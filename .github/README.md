# nix init action

[![check](https://github.com/spotdemo4/nix-init/actions/workflows/check.yaml/badge.svg?branch=main)](https://github.com/spotdemo4/nix-init/actions/workflows/check.yaml)
[![vulnerable](https://github.com/spotdemo4/nix-init/actions/workflows/vulnerable.yaml/badge.svg?branch=main)](https://github.com/spotdemo4/nix-init/actions/workflows/vulnerable.yaml)

composite action to initialize nix-based repos. Got tired of writing basically the same few steps for every job so this does all the important stuff in one:

- create a github app token (optional)
- checkout the repository
- setup git user for pushing changes
- install nix
- setup caching via [attic-action](https://github.com/ryanccn/attic-action) (optional)
- use development shell environment from flake (optional)

it usually runs in < 1 minute, and also works with self-hosted/gitea/forgejo action runners

## Usage

```yaml
- name: Initialize
  uses: spotdemo4/nix-init@v1.25.1
  with:
    shell: ci
    attic_endpoint: https://trev.zip/
    attic_cache: nixos
    attic_token: ${{ secrets.ATTIC_TOKEN }}
```

## Inputs

### `shell`

development shell environment to use from flake

```nix
# flake.nix
devShells.ci = pkgs.mkShell {
    packages = with pkgs; [
        flake-checker
    ];
};
```

```yaml
- name: Initialize
  uses: spotdemo4/nix-init@v1.25.1
  with:
    shell: ci

- name: Check flake
  run: flake-checker -f
```

### `attic_endpoint`, `attic_cache`, `attic_token`

options for [ryanccn/attic-action](https://github.com/ryanccn/attic-action) to use an attic cache

### `token`, `ref`, `fetch_depth`, `submodules`

options for [actions/checkout](https://github.com/actions/checkout)

### `app_id`, `app_key`

options for [actions/create-github-app-token](https://github.com/actions/create-github-app-token)

## Outputs

### `platform`

git platform (`github`/`gitea`/`forgejo`)

### `os`

runner operating system (`linux`/`darwin`/`windows`)

### `arch`

runner architecture (`amd64`/`arm64`/`arm`/`386`)

### `token`

token created by [actions/create-github-app-token](https://github.com/actions/create-github-app-token)

### `name`

the username from the token, used for git operations

### `email`

the email from the token, used for git operations

### `system`

the nix system platform (eg. `x86_64-linux`)
