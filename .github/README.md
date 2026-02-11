# nix init action

[![check](https://github.com/spotdemo4/nix-init/actions/workflows/check.yaml/badge.svg?branch=main)](https://github.com/spotdemo4/nix-init/actions/workflows/check.yaml)
[![vulnerable](https://github.com/spotdemo4/nix-init/actions/workflows/vulnerable.yaml/badge.svg?branch=main)](https://github.com/spotdemo4/nix-init/actions/workflows/vulnerable.yaml)

composite action to initialize nix-based repos. Got tired of writing basically the same few steps for every job so this does all the important stuff in one:

- create a github app token ([`actions/create-github-app-token`](https://github.com/actions/create-github-app-token)) (optional)
- checkout the repository ([`actions/checkout`](https://github.com/actions/checkout))
- setup git user for pushing changes
- setup optimal nix environment ([`wimpysworld/nothing-but-nix`](https://github.com/wimpysworld/nothing-but-nix))
- install nix ([`cachix/install-nix-action`](https://github.com/cachix/install-nix-action))
- set nix config equal to `nixConfig` in flake
- setup caching ([`spotdemo4/niks3-action`](https://github.com/spotdemo4/niks3-action)) (optional)
- use environment from flake ([`nicknovitski/nix-develop`](https://github.com/nicknovitski/nix-develop)) (optional)

it usually runs in < 1 minute, and works with self-hosted/gitea/forgejo action runners

## Usage

```yaml
- name: Initialize
  uses: spotdemo4/nix-init@v1.27.3
```

## Inputs

### `app_id`, `app_key`

options for [`actions/create-github-app-token`](https://github.com/actions/create-github-app-token)

### `token`, `ref`, `fetch_depth`, `submodules`

options for [`actions/checkout`](https://github.com/actions/checkout)

### `niks3_url`, `niks3_token`, `audience`

options for [`spotdemo4/niks3-action`](https://github.com/spotdemo4/niks3-action) to use a [niks3](https://github.com/Mic92/niks3) cache

### `shell`

option for [`nicknovitski/nix-develop`](https://github.com/nicknovitski/nix-develop) to load a development shell environment from a flake

```nix
# flake.nix
devShells.x86_64-linux.ci = pkgs.mkShell {
    packages = with pkgs; [
        flake-checker
    ];
};
```

```yaml
- name: Initialize
  uses: spotdemo4/nix-init@v1.27.3
  with:
    shell: ci

- name: Check flake
  run: flake-checker -f
```

## Outputs

### `platform`

git platform (`github`/`gitea`/`forgejo`)

### `os`

runner operating system (`linux`/`darwin`/`windows`)

### `arch`

runner architecture (`amd64`/`arm64`/`arm`/`386`)

### `token`

token created by [`actions/create-github-app-token`](https://github.com/actions/create-github-app-token)

### `name`

the username from the token, used for git operations

### `email`

the email from the token, used for git operations

### `system`

the nix system platform (eg. `x86_64-linux`)
