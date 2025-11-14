{
  description = "nix-init action";

  nixConfig = {
    extra-substituters = [
      "https://cache.trev.zip/nur"
    ];
    extra-trusted-public-keys = [
      "nur:70xGHUW1+1b8FqBchldaunN//pZNVo6FKuPL4U/n844="
    ];
  };

  inputs = {
    systems.url = "github:nix-systems/default";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    trev = {
      url = "github:spotdemo4/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      utils,
      trev,
      ...
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            trev.overlays.packages
            trev.overlays.libs
          ];
        };
      in
      {
        devShells = {
          default = pkgs.mkShell {
            packages = with pkgs; [
              bumper

              # nix
              nixfmt
            ];
            shellHook = pkgs.shellhook.ref;
          };

          ci = pkgs.mkShell {
            packages = with pkgs; [
              # update
              renovate

              # vulnerable
              flake-checker
              octoscan
            ];
          };
        };

        checks = pkgs.lib.mkChecks {
          nix = {
            src = ./.;
            deps = with pkgs; [
              nixfmt
            ];
            script = ''
              nixfmt -c flake.nix
            '';
          };

          actions = {
            src = ./.;
            deps = with pkgs; [
              prettier
              action-validator
              renovate
            ];
            script = ''
              prettier --check .
              action-validator action.yaml
              action-validator .github/**/*.yaml
              renovate-config-validator .github/renovate.json
            '';
          };
        };

        formatter = pkgs.nixfmt;
      }
    );
}
