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
      "${home-modules}/nushell.nix"
      "${home-modules}/desktop-common.nix"
      "${home-modules}/desktop-gdrive-keepassxc.nix"
      "${home-modules}/vivaldi.nix"

      "${home-modules}/hyprland.nix"

      # > VA-API is enabled by default for Intel GPUs [10] if you are using Firefox 115 or a later version. For other GPUs, set media.ffmpeg.vaapi.enabled to true in about:config.
      # from https://wiki.archlinux.org/title/Firefox#Hardware_video_acceleration
      "${home-modules}/firefox.nix"

      "${home-modules}/zoom.nix"
      "${home-modules}/wezterm.nix"
      # "${home-modules}/doom-emacs.nix" # emacs drains cpu for no reason :(
      "${home-modules}/nvim-lazy.nix"
      flake-inputs.hyprland.homeManagerModules.default

      "${home-modules}/zellij.nix"
      "${home-modules}/sbt.nix"
    ];

  xdg = {
    enable = true;
    configFile =
      let dotdir = "${config.home.homeDirectory}/nixos/dotfiles/hyprland";
      in {
        "hypr/local.conf".source =
          config.lib.file.mkOutOfStoreSymlink "${dotdir}/local.conf";
      };
  };

  # at the time of writing: for pointerCursor.gtk.enable
  gtk = {
    enable = true;
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
        signal-desktop
        tdesktop
        discord
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
        # v4l-utils # webcam utils
        radeontop
      ]) ++
      # packages from master
      (with pkgs.master; [ ]) ++
      # packages from other nixpkgs branches
      [ ];

    sessionVariables = { EDITOR = "nvim"; };

    pointerCursor = {
      gtk.enable = true;
      x11.enable = true;

      package = pkgs.phinger-cursors;
      name = "phinger-cursors-light";
      size = 64;
    };

    stateVersion = "22.11";
  };
}
