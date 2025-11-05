{
  description = "nix init action";

  nixConfig = {
    extra-substituters = [
      "https://cache.trev.zip/nur"
    ];
    extra-trusted-public-keys = [
      "nur:70xGHUW1+1b8FqBchldaunN//pZNVo6FKuPL4U/n844="
    ];
  };

  inputs = {
    systems.url = "systems";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    nur = {
      url = "github:spotdemo4/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    utils,
    nur,
    ...
  }:
    utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          nur.overlays.packages
          nur.overlays.libs
        ];
      };
    in {
      devShells = {
        default = pkgs.mkShell {
          packages = with pkgs; [
            bumper
          ];
          shellHook = pkgs.shellhook.ref;
        };

        ci = pkgs.mkShell {
          packages = with pkgs; [
            flake-checker
            renovate
          ];
        };
      };

      checks = pkgs.lib.mkChecks {
        nix = {
          src = ./.;
          deps = with pkgs; [
            alejandra
          ];
          script = ''
            alejandra -c .
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

      formatter = pkgs.alejandra;
    });
}
