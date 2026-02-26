# based on https://github.com/oxalica/rust-overlay#use-in-devshell-for-nix-develop
{
  description = "A Nix-devShell to build/develop this project";

  inputs = {
    # `nixpkgs-unstable` is fully ok for an application (i.e., not a NixOS-system)
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # `flake-utils` for easier nix-system handling
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlays = [ ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            # From https://github.com/dpc/htmx-sorta/blob/9e101583ec9391127b5bfcbe421e3ede2d627856/flake.nix#L83-L85
            # This is required to prevent a mangled bash shell in nix develop
            # see: https://discourse.nixos.org/t/interactive-bash-with-nix-develop-flake/15486
            (pkgs.lib.hiPrio pkgs.bashInteractive)
          ];

          buildInputs = with pkgs; [
            # often this becomes necessary sooner or later
            # openssl
          ];
        };
      }
    );
}
