# nix init action

![check](https://github.com/spotdemo4/nix-init/actions/workflows/check.yaml/badge.svg)
![vulnerable](https://github.com/spotdemo4/nix-init/actions/workflows/vulnerable.yaml/badge.svg)

composite action to initialize nix-based repos. Got tired of writing basically the same few steps for every job so this does all the important stuff in one:

- monitor network activity with harden-runner
- check if the action is a duplicate
- (optional) create a github app token
- checkout the repository
- setup git user for pushing changes
- install nix
- (optional) setup caching
  - [attic-action](https://github.com/ryanccn/attic-action)
  - [cachix-action](https://github.com/cachix/cachix-action)
- (optional) use development shell environment from flake

it usually runs in < 1 minute, and also works with self-hosted/gitea/forgejo action runners

## usage

```yaml
- name: Initialize
  uses: spotdemo4/nix-init@v1.8.4
  with:
    shell: ci
    attic_endpoint: https://trev.zip/
    attic_cache: nixos
    attic_token: ${{ secrets.ATTIC_TOKEN }}
```

## inputs

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
  uses: spotdemo4/nix-init@v1.8.4
  with:
    shell: ci

- name: Check flake
  run: flake-checker -f
```

### `attic_endpoint`, `attic_cache`, `attic_token`

options for [ryanccn/attic-action](https://github.com/ryanccn/attic-action) to use an attic cache

### `cachix_cache`, `cachix_token`, `cachix_key`

options for [cachix/cachix-action](https://github.com/cachix/cachix-action) to use a cachix cache

### `token`, `fetch_depth`

options for [actions/checkout](https://github.com/actions/checkout)

### `app_id`, `app_key`

options for [actions/create-github-app-token](https://github.com/actions/create-github-app-token)

## outputs

### `token`

token created by [actions/create-github-app-token](https://github.com/actions/create-github-app-token)

### `duplicate`

whether the action is a duplicate via [fkirc/skip-duplicate-actions](https://github.com/fkirc/skip-duplicate-actions)
