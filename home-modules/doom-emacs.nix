{ config, hlib, pkgs, flake-inputs, ... }@ha:
let
  base-emacs = pkgs.unstable.emacsUnstable;
  # base-emacs = pkgs.unstable.emacsUnstableGcc;
  emacs-with-pkgs =
    (pkgs.unstable.emacsPackagesFor base-emacs).emacsWithPackages
      (epkgs: (with epkgs; [ vterm ]));
  emacs-wrapped-for-doom = pkgs.lib.my.mkWrappedWithDeps {
    pkg = emacs-with-pkgs;
    pathsToWrap = [ "bin/emacs" "bin/emacs-*" ];
    extraWrapProgramArgs = [
      "--set"
      "DOOMDIR"
      ''"${config.home.sessionVariables.DOOMDIR}"''
      "--set"
      "DOOMLOCALDIR"
      ''"${config.home.sessionVariables.DOOMLOCALDIR}"''
    ];
    prefix-deps = with pkgs; [ ripgrep findutils fd ];
    suffix-deps = pkgs.lib.my.editorTools;
  };

  # path to the emacs directory from $HOME
  emacs-path = ".emacs.d";
in
{
  home = {
    packages = with pkgs; [
      emacs-wrapped-for-doom

      # TODO somehow get this into the wrapper?
      emacs-all-the-icons-fonts
    ];

    file.${emacs-path}.source = flake-inputs.doom-emacs;

    sessionPath = [ "$HOME/${emacs-path}/bin" ];
    sessionVariables = {
      DOOMDIR = "${config.xdg.configHome}/doom-emacs";
      DOOMPROFILELOADFILE =
        "${config.xdg.configHome}/doom-emacs/profiles/load.el";
      DOOMLOCALDIR = "${config.xdg.cacheHome}/doom-emacs";
    };
  };

  xdg = {
    enable = true;
    configFile =
      let dotdir = "${config.home.homeDirectory}/nixos/dotfiles/doom-emacs";
      in {
        "doom-emacs/config.el".source =
          config.lib.file.mkOutOfStoreSymlink "${dotdir}/config.el";
        "doom-emacs/init.el".source =
          config.lib.file.mkOutOfStoreSymlink "${dotdir}/init.el";
        "doom-emacs/packages.el".source =
          config.lib.file.mkOutOfStoreSymlink "${dotdir}/packages.el";
      };
  };

  # auto start emacs server
  services.emacs = {
    enable = true;
    package = emacs-wrapped-for-doom;

    # Starting with user session gives me a "DISPLAY:1 not found"
    # until I restart the service, so trying this instead.
    # -- Result: I don't really understand how to use this/how to
    # start emacs/the service with this, so have to disable it.
    # socketActivation.enable = true;
  };

  systemd.user.services.emacs = ha.lib.mkIf config.services.emacs.enable {
    Unit = {
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Install.WantedBy = ha.lib.mkForce [ "graphical-session.target" ];
  };
}
