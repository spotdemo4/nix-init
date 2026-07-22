#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Nick Novitski
# SPDX-License-Identifier: Apache-2.0
# Adapted from nicknovitski/nix-develop at commit 9be7cfb4b10451d3390a75dc18ad0465bed4932a.
# Modified for nix-init to use `nix print-dev-env` and avoid subprocesses.

set -euo pipefail
set +o posix

# Reserve private names so inherited export attributes cannot leak internals.
export -n __nd_arguments __nd_host_path __nd_host_names __nd_host_values \
	__nd_declaration __nd_host_name __nd_status_variable __nd_name __nd_value \
	__nd_nix_path __nd_i __nd_path_entry __nd_host_path_entry __nd_delimiter \
	__nd_dev_env __nd_status 2>/dev/null || true

__nd_arguments=("$@")
if ((${#__nd_arguments[@]} == 0)); then
	__nd_arguments=("./#default")
fi

__nd_contains() {
	[[ "$2" == *"$1"* ]]
}

IFS=":" read -r -a __nd_host_path <<<"$PATH"
__nd_host_names=()
__nd_host_values=()
while IFS= read -r __nd_declaration; do
	if [[ "$__nd_declaration" != "declare -x "*=* ]]; then
		continue
	fi
	__nd_host_name=${__nd_declaration#declare -x }
	__nd_host_name=${__nd_host_name%%=*}
	__nd_host_names+=("$__nd_host_name")
	__nd_host_values+=("${!__nd_host_name}")
done < <(export -p)

__nd_status_variable="__NIX_DEVELOP_STATUS_${RANDOM}_${RANDOM}_${RANDOM}"

exec 3>>"${GITHUB_ENV:-/dev/stderr}"
exec 4>>"${GITHUB_PATH:-/dev/stderr}"
exec 5>&1

# Iterate over the output of `env -0`. Shell output bypasses this stream on
# descriptor 5, and a private final record carries the command's exit status.
while IFS='=' read -r -d '' __nd_name __nd_value; do
	if [[ "$__nd_name" == "$__nd_status_variable" ]]; then
		exit "$__nd_value"
	fi

	if [[ "$__nd_name" == "PATH" ]]; then
		IFS=":" read -r -a __nd_nix_path <<<"$__nd_value"
		for ((__nd_i = ${#__nd_nix_path[@]} - 1; __nd_i >= 0; __nd_i--)); do
			__nd_path_entry="${__nd_nix_path[$__nd_i]}"
			if [[ "$__nd_path_entry" == *$'\n'* || ! -d "$__nd_path_entry" ]]; then
				continue
			fi
			for __nd_host_path_entry in "${__nd_host_path[@]}"; do
				if [[ "$__nd_path_entry" == "$__nd_host_path_entry" ]]; then
					continue 2
				fi
			done
			printf "%s\n" "$__nd_path_entry" >&4
		done
		continue
	fi

	if [[ ! "$__nd_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
		continue
	fi

	for ((__nd_i = 0; __nd_i < ${#__nd_host_names[@]}; __nd_i++)); do
		if [[ "$__nd_name" == "${__nd_host_names[$__nd_i]}" ]]; then
			if [[ "$__nd_value" == "${__nd_host_values[$__nd_i]}" ]]; then
				continue 2
			fi
			break
		fi
	done

	if [[ "$__nd_value" == *$'\n'* ]]; then
		__nd_delimiter="nix_develop_${RANDOM}_${RANDOM}_${RANDOM}_${RANDOM}"
		while __nd_contains "$__nd_delimiter" "$__nd_value"; do
			__nd_delimiter="${__nd_delimiter}_${RANDOM}"
		done
		printf "%s<<%s\n%s\n%s\n" "$__nd_name" "$__nd_delimiter" "$__nd_value" "$__nd_delimiter" >&3
		continue
	fi

	printf "%s=%s\n" "$__nd_name" "$__nd_value" >&3
done < <(
	set +e

	__nd_dev_env=$(nix print-dev-env "${__nd_arguments[@]}")
	__nd_status=$?
	if ((__nd_status != 0)); then
		printf '%s=%s\0' "$__nd_status_variable" "$__nd_status"
		exit 0
	fi

	exec 6>&1
	(
		set +e +u
		set +o pipefail
		exec 1>&5
		eval "$__nd_dev_env"
		env -0 >&6
	)
	__nd_status=$?
	printf '%s=%s\0' "$__nd_status_variable" "$__nd_status"
)

echo "Environment stream ended without an exit status" >&2
exit 1
