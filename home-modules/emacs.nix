{ inputs, lib, ... }:
{ config, pkgs, ... }:
let
  emacs-wrapped-for-doom = lib.mkWrappedWithDeps {
    pkg = pkgs.emacs;
    pathsToWrap = [ "bin/emacs" "bin/emacs-*" ];
    deps = with pkgs; [
      ripgrep
      findutils
      fd
      shellcheck
      multimarkdown
      nixfmt
      jq
      editorconfig-core-c
    ];
  };
in {
  home = {
    packages = with pkgs; [
      emacs-wrapped-for-doom

      # TODO somehow get this into the wrapper?
      emacs-all-the-icons-fonts
    ];

    sessionPath = [ "$HOME/.emacs.d/bin" ];
  };
}
