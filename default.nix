{
  nixpkgs ? (
    with (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
    derivation {
      name = "source";
      system = builtins.currentSystem;
      builder = "/bin/sh";
      args = [
        "-c"
        "echo 'Run `nix flake archive` to fetch nixpkgs.' && exit 1"
      ];
      outputHashAlgo = "sha256";
      outputHash = narHash;
      outputHashMode = "recursive";
    }
  ),
  config ? { },
  overlays ? [ ],
  ...
}@args:
import nixpkgs (
  {
    config = import ./nixpkgs-config.nix // config;
    overlays = [ (import ./pkgs) ] ++ overlays;
  }
  // removeAttrs args [
    "config"
    "overlays"
  ]
)
