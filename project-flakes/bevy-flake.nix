# based on https://github.com/oxalica/rust-overlay#use-in-devshell-for-nix-develop
{
  description = "A Nix-devShell to build/develop this project";

  inputs = {
    # `nixpkgs-unstable` is fully ok for an application (i.e., not a NixOS-system)
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # `rust-overlay` can give us a rust-version that is in-sync with rust-toolchain.toml
    # rust-overlay.url = "github:oxalica/rust-overlay";

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

        # use rust-version + components from the rust-toolchain.toml file
        # rust-toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
      in
      {
        devShells.default = pkgs.mkShell rec {
          nativeBuildInputs = with pkgs; [
            # from https://github.com/bevyengine/bevy/blob/main/docs/linux_dependencies.md#Nix
            pkg-config

            # from https://bevyengine.org/learn/book/getting-started/setup/#enable-fast-compiles-optional
            mold-wrapped
            clang

            # rust-toolchain

            # From https://github.com/dpc/htmx-sorta/blob/9e101583ec9391127b5bfcbe421e3ede2d627856/flake.nix#L83-L85
            # This is required to prevent a mangled bash shell in nix develop
            # see: https://discourse.nixos.org/t/interactive-bash-with-nix-develop-flake/15486
            (pkgs.hiPrio pkgs.bashInteractive)
          ];

          buildInputs = with pkgs; [
            # common bevy dependencies
            udev
            alsa-lib
            vulkan-loader

            # bevy x11 feature
            xorg.libX11
            xorg.libXcursor
            xorg.libXi
            xorg.libXrandr

            # bevy wayland feature
            libxkbcommon
            wayland

            # often this becomes necessary sooner or later
            # openssl
          ];

          # from bevy setup as well
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath buildInputs;

          # Some environment to make rust-analyzer work correctly (Still the path prefix issue)
          # See https://github.com/oxalica/rust-overlay/issues/129
          # RUST_SRC_PATH = "${rust-toolchain}/lib/rustlib/src/rust/library";
        };
      }
    );
}
