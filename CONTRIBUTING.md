# contributing

## requirements

- [nix](https://nixos.org/)

## getting started

```sh
nix develop
```

with [direnv](https://direnv.net/):

```sh
ln -s .envrc.project .envrc
direnv allow
```

### format

```sh
nix fmt
```

with [oxfmt](https://oxc.rs/):

```sh
oxfmt --write .
```

### check

```sh
nix flake check
```

with [node](https://nodejs.org/) and [oxlint](https://oxc.rs/):

```sh
node --test nix-develop/nix-develop.test.mjs
oxlint --deny-warnings
```

### release

with [bumper](https://trev.zip/llc/bumper):

```sh
bumper
```

releases are automatically created for [significant](https://www.conventionalcommits.org/en/v1.0.0/#summary) changes
