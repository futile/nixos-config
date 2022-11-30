{ inputs, lib, ... }:
{ config, pkgs, ... }:
let
  base-emacs = pkgs.unstable.emacsNativeComp;
  # base-emacs = pkgs.unstable.emacsUnstableGcc;
  emacs-with-pkgs = (pkgs.unstable.emacsPackagesFor base-emacs).emacsWithPackages
    (epkgs: (with epkgs; [ vterm ]));
  emacs-wrapped-for-doom = lib.mkWrappedWithDeps {
    pkg = emacs-with-pkgs;
    pathsToWrap = [ "bin/emacs" "bin/emacs-*" ];
    extraWrapProgramArgs = [
      "--set" "DOOMDIR" ''"${config.home.sessionVariables.DOOMDIR}"''
      "--set" "DOOMLOCALDIR" ''"${config.home.sessionVariables.DOOMLOCALDIR}"''
    ];
    prefix-deps = with pkgs; [
      ripgrep
      findutils
      fd
    ];
    suffix-deps = with pkgs; [
      # misc
      multimarkdown
      jq
      editorconfig-core-c

      # shell
      shfmt
      shellcheck

      # python
      python-language-server
      black
      python38Packages.pyflakes
      python38Packages.isort

      # nix
      nixfmt

      # tex
      texlab

      # scala
      metals
    ];
  };

  # path to the emacs directory from $HOME
  emacs-path = ".emacs.d";

  # based on https://discourse.nixos.org/t/advice-needed-installing-doom-emacs/8806/8
  onChangeScript = "${pkgs.writeShellScript "doom-change" ''
        export DOOMDIR="${config.home.sessionVariables.DOOMDIR}"
        export DOOMLOCALDIR="${config.home.sessionVariables.DOOMLOCALDIR}"
        export DOOMPROFILELOADFILE="${config.home.sessionVariables.DOOMPROFILELOADFILE}"
        if [ ! -d "$DOOMLOCALDIR" ]; then
          "$HOME/${emacs-path}/bin/doom" -y install --no-env
        else
          "$HOME/${emacs-path}/bin/doom" sync
        fi
     ''}";
in {
  home = {
    packages = with pkgs; [
      emacs-wrapped-for-doom

      # TODO somehow get this into the wrapper?
      emacs-all-the-icons-fonts
    ];

    file.${emacs-path} = {
      source = inputs.doom-emacs;
      # onChange = onChangeScript;
    };

    sessionPath = [ "$HOME/${emacs-path}/bin" ];
    sessionVariables = {
      DOOMDIR = "${config.xdg.configHome}/doom-emacs";
      DOOMPROFILELOADFILE="${config.xdg.configHome}/doom-emacs/profiles/load.el";
      DOOMLOCALDIR = "${config.xdg.cacheHome}/doom-emacs";
    };
  };

  xdg = {
    enable = true;
    configFile."doom-emacs" = {
      source = ../dotfiles/doom-emacs;
      recursive = true;
      # onChange = onChangeScript;
    };
  };
}
