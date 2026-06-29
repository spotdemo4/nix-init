{
  lockFile ? ./flake.lock,
  id ? "nix-init-nixpkgs",
}:
let
  lock = builtins.fromJSON (builtins.readFile lockFile);
  root = lock.nodes.${lock.root};
  nixpkgs = lock.nodes.${root.inputs.nixpkgs};
in
{
  version = 2;
  flakes = [
    {
      from = {
        type = "indirect";
        inherit id;
      };
      to = nixpkgs.locked;
    }
  ];
}
