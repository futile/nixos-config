# based on https://rustc-dev-guide.rust-lang.org/building/suggested.html#using-nix-shell
{
  description = "A Nix-devShell to build/develop rustc";

  inputs = {
    # `nixpkgs-unstable` is fully ok for an application (i.e., not a NixOS-system)
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      overlays = [ ];
      pkgs = import nixpkgs {
        inherit system overlays;
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        name = "rustc-dev";

        nativeBuildInputs = with pkgs; [
          binutils
          cmake
          ninja
          pkg-config
          python3
          git
          curl
          cacert
          patchelf
          nix

          # From https://github.com/dpc/htmx-sorta/blob/9e101583ec9391127b5bfcbe421e3ede2d627856/flake.nix#L83-L85
          # This is required to prevent a mangled bash shell in nix develop
          # see: https://discourse.nixos.org/t/interactive-bash-with-nix-develop-flake/15486
          (pkgs.hiPrio pkgs.bashInteractive)
        ];

        buildInputs = with pkgs; [
          openssl
          glibc.out
          glibc.static
        ];

        # Avoid creating text files for ICEs.
        RUSTC_ICE = "0";

        # Provide `libstdc++.so.6` for the self-contained lld.
        # also see https://discourse.nixos.org/t/how-to-solve-libstdc-not-found-in-shell-nix/25458/6
        LD_LIBRARY_PATH = "${with pkgs; lib.makeLibraryPath [
            stdenv.cc.cc.lib
          ]}";
      };
    };
}
