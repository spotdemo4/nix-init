#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Nick Novitski
# SPDX-License-Identifier: Apache-2.0
# Adapted from nicknovitski/nix-develop at commit 9be7cfb4b10451d3390a75dc18ad0465bed4932a.
# Modified for nix-init to use `nix print-dev-env` and avoid subprocesses.

set -euo pipefail

arguments=("$@")
if ((${#arguments[@]} == 0)); then
	arguments=("./#default")
fi

contains() {
	[[ "$2" == *"$1"* ]]
}

IFS=":" read -r -a host_path <<<"$PATH"
status_variable="__NIX_DEVELOP_STATUS_${RANDOM}_${RANDOM}_${RANDOM}"

exec 3>>"${GITHUB_ENV:-/dev/stderr}"
exec 4>>"${GITHUB_PATH:-/dev/stderr}"
exec 5>&1

# Iterate over the output of `env -0`. Shell output bypasses this stream on
# descriptor 5, and a private final record carries the command's exit status.
while IFS='=' read -r -d '' name value; do
	if [[ "$name" == "$status_variable" ]]; then
		exit "$value"
	fi

	if [[ "$name" == "PATH" ]]; then
		IFS=":" read -r -a nix_path <<<"$value"
		for ((i = ${#nix_path[@]} - 1; i >= 0; i--)); do
			path_entry="${nix_path[$i]}"
			if [[ "$path_entry" == *$'\n'* || ! -d "$path_entry" ]]; then
				continue
			fi
			for host_path_entry in "${host_path[@]}"; do
				if [[ "$path_entry" == "$host_path_entry" ]]; then
					continue 2
				fi
			done
			printf "%s\n" "$path_entry" >&4
		done
		continue
	fi

	if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
		continue
	fi

	if [[ "${!name+x}" == x ]] && [[ "${!name}" == "$value" ]]; then
		continue
	fi

	if [[ "$value" == *$'\n'* ]]; then
		delimiter="nix_develop_${RANDOM}_${RANDOM}_${RANDOM}_${RANDOM}"
		while contains "$delimiter" "$value"; do
			delimiter="${delimiter}_${RANDOM}"
		done
		printf "%s<<%s\n%s\n%s\n" "$name" "$delimiter" "$value" "$delimiter" >&3
		continue
	fi

	printf "%s=%s\n" "$name" "$value" >&3
done < <(
	set +e

	dev_env=$(nix print-dev-env "${arguments[@]}")
	status=$?
	if ((status != 0)); then
		printf '%s=%s\0' "$status_variable" "$status"
		exit 0
	fi

	exec 6>&1
	(
		set +e +u
		set +o pipefail
		exec 1>&5
		eval "$dev_env"
		env -0 >&6
	)
	status=$?
	printf '%s=%s\0' "$status_variable" "$status"
)

echo "Environment stream ended without an exit status" >&2
exit 1
