# first set of args is passed by us
{ inputs, lib, ... }@outer_args:
# second set of args is passed by home-manager
{ config, pkgs, ... }:
let
  my-google-drive-ocamlfuse = pkgs.google-drive-ocamlfuse;
  my-keepassxc = pkgs.unstable.keepassxc;
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
  programs.direnv.enableNixDirenvIntegration = true;

  programs.fzf.enable = true;

  # nix-index
  # not available for 20.09 :()
  # programs.nix-index.enable = true;

  home = {
    packages =
      # bound packages
      [
        my-google-drive-ocamlfuse
        my-keepassxc
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
      ]) ++
      # packages from unstable
      (with pkgs.unstable; [
        spotify
        pavucontrol
        vivaldi
        vivaldi-ffmpeg-codecs
        # element-desktop # known bug: https://github.com/NixOS/nixpkgs/issues/120228
        tdesktop
        signal-desktop
        dtrx
        vscode
        zoom-us
        rustup
        cargo-edit
        rust-analyzer
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
        discord
      ]) ++
      # packages from master
      (with pkgs.master; [
      ])
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
