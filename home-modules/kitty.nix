{
  config,
  pkgs,
  flake-inputs,
  thisFlakePath,
  ...
}:
pkgs.lib.mkIf pkgs.stdenv.isLinux {
  home.packages = [ pkgs.kitty ];

  xdg = {
    enable = true;

    configFile."kitty/kitty.conf".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/kitty/kitty.conf";
    configFile."kitty/noctalia.conf.template".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/kitty/noctalia.conf.template";
    configFile."kitty/colors/lume.conf".source =
      flake-inputs.lume-theme + "/terminals/kitty/lume.conf";
    configFile."kitty/theme.conf".text = ''
      include colors/lume.conf
    '';
  };
}
