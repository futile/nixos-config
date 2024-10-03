{ config, pkgs, ... }:
let
  base-zed = pkgs.zed-editor;
  my-zed = pkgs.lib.my.mkWrappedWithDeps {
    pkg = base-zed;
    pathsToWrap = [ "bin/zeditor" ];
    extraWrapProgramArgs = [ ];
    prefix-deps = with pkgs; [ ripgrep findutils fd ];
    suffix-deps = pkgs.lib.my.editorTools;
  };
in
{
  home = {
    packages = [ my-zed ];
  };

  xdg = {
    enable = true;
    configFile = {
      "zed".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dotfiles/zed";
    };
  };
}
