{ config, pkgs, ... }:
let
  base-helix = pkgs.unstable.helix;
  helix-wrapped = pkgs.lib.my.mkWrappedWithDeps {
    pkg = base-helix;
    pathsToWrap = [ "bin/hx" ];
    suffix-deps = pkgs.lib.my.editorTools;
  };
in {
  programs.helix = {
    enable = true;
    package = helix-wrapped;
  };

  # for working system clipboard
  home.packages = with pkgs.unstable; [ xsel ];

  xdg = {
    enable = true;
    configFile."helix/config.toml".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nixos/dotfiles/helix/config.toml";
    configFile."helix/languages.toml".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nixos/dotfiles/helix/languages.toml";
  };
}
