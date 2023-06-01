{ config, pkgs, flake-inputs, thisFlakePath, ... }:
let flakeRoot = flake-inputs.self.outPath;
in {
  imports =
    let home-modules = "${flakeRoot}/home-modules";
    in [
      "${home-modules}/base.nix"
      "${home-modules}/shell-common.nix"
      "${home-modules}/helix.nix"
      "${home-modules}/git.nix"
      "${home-modules}/fish.nix"
      "${home-modules}/desktop-common.nix"
      "${home-modules}/desktop-gdrive-keepassxc.nix"
      "${home-modules}/vivaldi.nix"
      "${home-modules}/zoom.nix"
      "${home-modules}/wezterm.nix"
      "${home-modules}/doom-emacs.nix"
    ];

  home = {
    packages =
      # bound packages
      [ ] ++
      # packages from stable
      (with pkgs; [
        element-desktop # temp stable, until bug resolved

        # compile stuff, for convenience I guess; but generally want to get rid of it
        ccache
        gcc
        gdb
      ]) ++
      # packages from unstable
      (with pkgs.unstable; [
        # messengers
        signal-desktop
        tdesktop
        discord
        slack
        # element-desktop # known bug: https://github.com/NixOS/nixpkgs/issues/120228

        # rust tools
        rustup
        cargo-edit
        # rust-analyzer # conflicts with rustup, probably provided by rustup now?

        # misc
        texlive.combined.scheme-full
        zotero
        protonvpn-cli

        # hardware stuff
        v4l_utils # webcam utils
      ]) ++
      # packages from master
      (with pkgs.master; [ ]) ++
      # packages from other nixpkgs branches
      [ ];

    sessionVariables = { EDITOR = "vim"; };

    stateVersion = "22.05";
  };
}