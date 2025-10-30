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
        overlays = [nur.overlays.default];
      };
    in {
      devShells = {
        default = pkgs.mkShell {
          packages = with pkgs; [
            trev.bumper
          ];
          shellHook = pkgs.trev.shellhook.ref;
        };

        ci = pkgs.mkShell {
          packages = with pkgs; [
            flake-checker
            trev.renovate
          ];
        };
      };

      checks = pkgs.trev.lib.mkChecks {
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
            trev.renovate
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
