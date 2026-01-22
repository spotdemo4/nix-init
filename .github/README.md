# nix init action

[![check](https://github.com/spotdemo4/nix-init/actions/workflows/check.yaml/badge.svg?branch=main)](https://github.com/spotdemo4/nix-init/actions/workflows/check.yaml)
[![vulnerable](https://github.com/spotdemo4/nix-init/actions/workflows/vulnerable.yaml/badge.svg?branch=main)](https://github.com/spotdemo4/nix-init/actions/workflows/vulnerable.yaml)

composite action to initialize nix-based repos. Got tired of writing basically the same few steps for every job so this does all the important stuff in one:

- monitor network activity with harden-runner
- (optional) create a github app token
- checkout the repository
- setup git user for pushing changes
- install nix
- (optional) setup caching
  - [attic-action](https://github.com/ryanccn/attic-action)
  - [cachix-action](https://github.com/cachix/cachix-action)
- (optional) use development shell environment from flake

it usually runs in < 1 minute, and also works with self-hosted/gitea/forgejo action runners

## Usage

```yaml
- name: Initialize
  uses: spotdemo4/nix-init@v1.18.0
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
  uses: spotdemo4/nix-init@v1.18.0
  with:
    shell: ci

- name: Check flake
  run: flake-checker -f
```

### `attic_endpoint`, `attic_cache`, `attic_token`

options for [ryanccn/attic-action](https://github.com/ryanccn/attic-action) to use an attic cache

### `token`, `fetch_depth`

options for [actions/checkout](https://github.com/actions/checkout)

### `app_id`, `app_key`

options for [actions/create-github-app-token](https://github.com/actions/create-github-app-token)

## Outputs

### `token`

token created by [actions/create-github-app-token](https://github.com/actions/create-github-app-token)

### `user`

the username from the token, used for git operations

### `system`

the nix system platform (eg. `x86_64-linux`)
