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
    "${home-modules}/doom-emacs.nix"
    "${home-modules}/helix.nix"
    "${home-modules}/git.nix"
    "${home-modules}/fish.nix"
  ];

  # starship prompt: https://starship.rs
  # programs.starship = {
  #   enable = true;
  #   package = pkgs.unstable.starship;
  # };

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
        xsel # for system clipboard with terminal emulators that ignore clipboard escape codes (for security reasons), such as wezterm
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
        zoom-us
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
        wezterm
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

  xdg = {
    enable = true;

    # wezterm
    configFile."wezterm/wezterm.lua".source =
      config.lib.file.mkOutOfStoreSymlink
      "${thisFlakePath}/dotfiles/wezterm/wezterm.lua";
    configFile."wezterm/colors/everforest.toml".source =
      flake-inputs.wezterm-everforest + "/everforest.toml";

    # starship
    configFile."starship.toml".source = config.lib.file.mkOutOfStoreSymlink
      "${thisFlakePath}/dotfiles/starship.toml";

    # from https://github.com/NixOS/nixpkgs/issues/107233#issuecomment-757424877
    # -> do this by hand instead, as the file contains a lot of entries by default. (19.4.21)
    # ".config/zoomus.conf".text = ''
    #   enableWaylandShare=true
    # '';
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
