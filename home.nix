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
  thisFlakePath = config.home.homeDirectory + "/nixos";
in
{
  programs.home-manager.enable = true;

  imports =
    let
      mkHomeModule = path: (import path outer_args);
    in
    map mkHomeModule [
      ./home-modules/doom-emacs.nix
      ./home-modules/helix.nix
      ./home-modules/git.nix
      ./home-modules/fish.nix
    ];

  # direnv & nix-direnv
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  programs.fzf.enable = true;
  programs.zoxide.enable = true;

  programs.exa = {
    enable = true;
    # enableAliases = true;
    package = pkgs.unstable.exa;
  };

  # nix-index
  programs.nix-index.enable = true;

  # starship prompt: https://starship.rs
  programs.starship = {
    enable = true;
    package = pkgs.unstable.starship;
  };

  home = {
    stateVersion = "22.05";

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
        python3
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
        xsel # for system clipboard with terminal emulators that ignore clipboard escape codes (for security reasons), such as wezterm
        nixpkgs-fmt
      ]) ++
      # packages from unstable
      (with pkgs.unstable; [
        spotify
        pavucontrol
        # element-desktop # known bug: https://github.com/NixOS/nixpkgs/issues/120228
        signal-desktop
        dtrx # removed from upstream because abandoned, but this looks good: https://pypi.org/project/dtrx/#description; should be back in
        # vscode # don't need this atm, so why install it?
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
        wezterm
        firefox
      ]) ++
      # packages from master
      (with pkgs.master; [
      ]) ++
      # packages from other nixpkgs branches
      [
      ]
    ;

    file = {
      "bin".source = config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/bin";
    };

    sessionPath = [ "$HOME/bin" ];

    sessionVariables = {
      EDITOR = "vim";
    };
  };

  xdg = {
    enable = true;

    # wezterm
    configFile."wezterm/wezterm.lua".source = config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/wezterm/wezterm.lua";
    configFile."wezterm/colors/everforest.toml".source = inputs.wezterm-everforest + "/everforest.toml";

    # starship
    configFile."starship.toml".source = config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/starship.toml";

    # from https://github.com/NixOS/nixpkgs/issues/107233#issuecomment-757424877
    # -> do this by hand instead, as the file contains a lot of entries by default. (19.4.21)
    # ".config/zoomus.conf".text = ''
    #   enableWaylandShare=true
    # '';
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
