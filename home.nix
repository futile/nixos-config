# first set of args is passed by us
{ inputs, lib, ... }@outer_args:
# second set of args is passed by home-manager
{ config, pkgs, ... }:
let
  my-google-drive-ocamlfuse = pkgs.google-drive-ocamlfuse;
  my-keepassxc = pkgs.unstable.keepassxc;
  vivaldi-pkgs = pkgs.unstable;
  my-vivaldi = vivaldi-pkgs.vivaldi.overrideAttrs (_: {
    proprietaryCodecs = true;
    vivaldi-ffmpeg-codes = vivaldi-pkgs.vivaldi-ffmpeg-codecs;
    enableWidevine = true;
    vivaldi-widevine = vivaldi-pkgs.vivaldi-widevine;
  });
in
{
  programs.home-manager.enable = true;

  imports = let 
    mkHomeModule = path: (import path outer_args);
  in map mkHomeModule [
    ./home-modules/doom-emacs.nix
    ./home-modules/git.nix
    ./home-modules/fish.nix
  ];

  # direnv & nix-direnv
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  programs.fzf.enable = true;
  programs.zoxide.enable = true;

  # nix-index
  programs.nix-index.enable = true;

  home = {
    packages =
      # bound packages
      [
        my-google-drive-ocamlfuse
        my-keepassxc
        my-vivaldi
      ] ++
      # packages from stable
      (with pkgs;
      [
        htop
        ripgrep
        fd
        bat
        python39
        element-desktop # temp stable, until bug resolved
        file
        procs # TODO move config from `~/.config/procs/config.toml` into this repo # stable, because fish completion on unstable is broken
        sshuttle
        ccache
        libreoffice
        gcc
        gdb
        tree
        lsof
        valgrind
        tilix
        killall
      ]) ++
      # packages from unstable
      (with pkgs.unstable; [
        spotify
        pavucontrol
        # element-desktop # known bug: https://github.com/NixOS/nixpkgs/issues/120228
        signal-desktop
        dtrx # removed from upstream because abandoned, but this looks good: https://pypi.org/project/dtrx/#description; should be back in
        vscode
        zoom-us
        rustup
        cargo-edit
        rust-analyzer
        tdesktop
        protonvpn-cli
        lxappearance
        nitrogen
        nix-prefetch-git
        nix-prefetch-github
        nixpkgs-review
        xsettingsd
        texlive.combined.scheme-full
        inkscape
        gimp
        spectacle
        zellij
        discord
        just
        obsidian
        tokei
        v4l_utils # webcam utils
        zotero
      ]) ++
      # packages from master
      (with pkgs.master; [
      ]) ++
      # packages from other nixpkgs branches
      [
      ]
    ;

    file = {
      # from https://github.com/NixOS/nixpkgs/issues/107233#issuecomment-757424877
      # -> do this by hand instead, as the file contains a lot of entries by default. (19.4.21)
      # ".config/zoomus.conf".text = ''
      #   enableWaylandShare=true
      # '';
    };

    sessionVariables = {
      EDITOR = "vim";
    };
  };

  systemd.user.services = {
    google-drive-ocamlfuse = {
      Unit = {
        Description = "Automount google drive";
      };

      Service = {
        Type = "simple";
        ExecStart = "${my-google-drive-ocamlfuse}/bin/google-drive-ocamlfuse -f %h/GoogleDrive";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    keepassxc = {
      Unit = {
        Description = "Autostart Keepassxc";
        After = [ "graphical-session-pre.target" "google-drive-ocamlfuse.service" ];
        Wants = [ "google-drive-ocamlfuse.service" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${my-keepassxc}/bin/keepassxc";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
