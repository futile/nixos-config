# first set of args is passed by us
{ inputs }: 
# second set of args is passed by home-manager
{ config, pkgs, ... }:
{
  programs.home-manager.enable = true;

  home = {
    packages = 
      # packages from stable
      with pkgs; [
        htop
        ripgrep
        fd
        bat
        python39
        element-desktop # temp stable, until bug resolved
      ] ++ 
      # packages from unstable
      (with pkgs.unstable; [
        spotify
        vivaldi
        vivaldi-ffmpeg-codecs
        # element-desktop # known bug: https://github.com/NixOS/nixpkgs/issues/120228
        tdesktop
        keepassxc
        dtrx
        vscode
        zoom-us
      ]);

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

  programs.git = {
    enable = true;
    package = pkgs.gitAndTools.gitFull;
    userName = "Felix Rath";

    extraConfig = {
      core = {
        editor = "vim";
      };
      pull = {
        ff = "only";
      };
    };

    delta = {
      enable = true;
      options = {
        syntax-theme = "GitHub";
      };
    };

    lfs.enable = true;
  };

  programs.fish = {
    enable = true;

    plugins = [
      {
        name = "foreign-env";
        src = inputs.fish-foreign-env;
      }
    ];

    functions = {
      does_my_fish_config_work = {
        body = ''
          echo "yes it does"
        '';
      };
    };

    # do I need this? or already done by nix/home-manager?
    # this is already done by nixos actually (through a systemd-service I think),
    # seems to only be needed when running nix on a non-nixos system.
    # loginShellInit = ''
    #   if test -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    #     fenv source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    #   end

    #   if test -e /nix/var/nix/profiles/default/etc/profile.d/nix.sh
    #     fenv source /nix/var/nix/profiles/default/etc/profile.d/nix.sh
    #   end
    # '';
  };
}
