# nix init action

[![check status](https://img.shields.io/github/actions/workflow/status/spotdemo4/nix-init/check.yaml?logo=GitHub&logoColor=%23cdd6f4&label=check&labelColor=%2311111b)](https://github.com/spotdemo4/nix-init/actions/workflows/check.yaml)
[![vulnerable status](https://img.shields.io/github/actions/workflow/status/spotdemo4/nix-init/vulnerable.yaml?logo=nixos&logoColor=%2389dceb&label=vulnerable&labelColor=%2311111b)](https://github.com/spotdemo4/nix-init/actions/workflows/vulnerable.yaml)

composite action to initialize nix-based repos. Got tired of writing basically the same few steps for every job so this does all the important stuff in one:

- monitor network activity with harden-runner
- checkout the repository
- install nix
- setup caching
  - [nix-simple-cache-action](https://github.com/spotdemo4/nix-simple-cache-action) (default)
  - [attic-action](https://github.com/ryanccn/attic-action)
  - [cachix-action](https://github.com/cachix/cachix-action)
- (optional) use development shell environment from flake

it usually runs in < 1 minute, and also works with self-hosted/gitea/forgejo action runners

## usage

```yaml
- name: Initialize
  uses: spotdemo4/nix-init@v1.0.0
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
  uses: spotdemo4/nix-init@v1.0.0
  with:
    shell: ci

- name: Check flake
  run: flake-checker -f
```

### `attic_endpoint`, `attic_cache`, `attic_token`

options for [ryanccn/attic-action](https://github.com/ryanccn/attic-action) to use an attic cache

### `cachix_cache`, `cachix_token`, `cachix_key`

options for [cachix/cachix-action](https://github.com/cachix/cachix-action) to use a cachix cache
