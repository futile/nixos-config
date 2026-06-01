{
  config,
  pkgs,
  flake-inputs,
  thisFlakePath,
  ...
}:
{
  home.packages = pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.kitty ];

  xdg = pkgs.lib.mkIf pkgs.stdenv.isLinux {
    enable = true;

    configFile."kitty/kitty.conf".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/kitty/kitty.conf";
    configFile."kitty/noctalia.conf.template".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/kitty/noctalia.conf.template";
    configFile."kitty/themes/lume.conf".source =
      flake-inputs.lume-theme + "/terminals/kitty/lume.conf";
    configFile."kitty/theme.conf".text = ''
      include themes/lume.conf
    '';
  };
}
