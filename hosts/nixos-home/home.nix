{ config, pkgs, flake-inputs, thisFlakePath, ... }:
let
  my-google-drive-ocamlfuse = pkgs.google-drive-ocamlfuse;
  my-keepassxc = pkgs.unstable.keepassxc;
  flakeRoot = flake-inputs.self.outPath;
in {
  imports = let home-modules = "${flakeRoot}/home-modules";
  in [
    "${home-modules}/base.nix"
    "${home-modules}/shell-common.nix"
    "${home-modules}/vivaldi.nix"
    "${home-modules}/zoom.nix"
    "${home-modules}/wezterm.nix"
    "${home-modules}/doom-emacs.nix"
    "${home-modules}/helix.nix"
    "${home-modules}/git.nix"
    "${home-modules}/fish.nix"
  ];

  home = {
    stateVersion = "22.05";

    packages =
      # bound packages
      [ my-google-drive-ocamlfuse my-keepassxc ] ++
      # packages from stable
      (with pkgs; [
        python3
        element-desktop # temp stable, until bug resolved
        ccache
        libreoffice
        gcc
        gdb
        nixpkgs-fmt

        # stuff I don't use atm
        # procs # TODO move config from `nixos-home:~/.config/procs/config.toml` into this repo # stable, because fish completion on unstable is broken
        # sshuttle
        # tree
        # valgrind
        # tilix
      ]) ++
      # packages from unstable
      (with pkgs.unstable; [
        spotify
        pavucontrol
        # element-desktop # known bug: https://github.com/NixOS/nixpkgs/issues/120228
        signal-desktop
        dtrx
        rustup
        cargo-edit
        # rust-analyzer # conflicts with rustup, probably provided by rustup now?
        tdesktop
        protonvpn-cli
        nix-prefetch-git
        nix-prefetch-github
        nixpkgs-review
        texlive.combined.scheme-full
        inkscape
        gimp
        spectacle
        discord
        just
        obsidian
        tokei
        v4l_utils # webcam utils
        zotero
        firefox
        trippy
        slack
        magic-wormhole

        # stuff I don't use atm
        # vscode
        # zellij
        # xsettingsd
        # lxappearance
        # nitrogen
      ]) ++
      # packages from master
      (with pkgs.master; [ ]) ++
      # packages from other nixpkgs branches
      [ ];

    sessionVariables = { EDITOR = "vim"; };
  };

  systemd.user.services = {
    google-drive-ocamlfuse = {
      Unit = { Description = "Automount google drive"; };

      Service = {
        Type = "simple";
        ExecStart =
          "${my-google-drive-ocamlfuse}/bin/google-drive-ocamlfuse -f %h/GoogleDrive";
      };

      Install = { WantedBy = [ "default.target" ]; };
    };

    keepassxc = {
      Unit = {
        Description = "Autostart Keepassxc";
        After =
          [ "graphical-session-pre.target" "google-drive-ocamlfuse.service" ];
        Wants = [ "google-drive-ocamlfuse.service" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${my-keepassxc}/bin/keepassxc";
      };

      Install = { WantedBy = [ "graphical-session.target" ]; };
    };
  };
}
