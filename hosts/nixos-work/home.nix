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
      "${home-modules}/firefox.nix"
      "${home-modules}/zoom.nix"
      "${home-modules}/wezterm.nix"
      "${home-modules}/doom-emacs.nix"
      "${home-modules}/nvim-lazy.nix"
      flake-inputs.hyprland.homeManagerModules.default
    ];

  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = "source = ~/.config/hypr/local.conf";
  };

  xdg = {
    enable = true;
    configFile =
      let dotdir = "${config.home.homeDirectory}/nixos/dotfiles/hyprland";
      in {
        "hypr/local.conf".source =
          config.lib.file.mkOutOfStoreSymlink "${dotdir}/local.conf";
      };
  };

  home = {
    packages =
      # bound packages
      [ ] ++
      # packages from stable
      (with pkgs; [
        # compile stuff, for convenience I guess; but generally want to get rid of it
        ccache
        gcc
        gdb
      ]) ++
      # packages from unstable
      (with pkgs.unstable;
      [
        # messengers
        slack
        # element-desktop # known bug: https://github.com/NixOS/nixpkgs/issues/120228

        # rust tools
        rustup
        cargo-edit

        # misc
        # texlive.combined.scheme-full
        # zotero
        # protonvpn-cli

        # hardware stuff
        # v4l_utils # webcam utils
      ]) ++
      # packages from master
      (with pkgs.master; [ ]) ++
      # packages from other nixpkgs branches
      [ ];

    sessionVariables = { EDITOR = "nvim"; };

    stateVersion = "22.11";
  };
}
