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
    # Kitty/Noctalia notification history cleanup; see
    # docs/superpowers/plans/2026-06-04-kitty-noctalia-notification-footers.md.
    configFile."kitty/notifications.py".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/kitty/notifications.py";
    configFile."kitty/codex-noctalia-watcher.py".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/kitty/codex-noctalia-watcher.py";
    configFile."kitty/noctalia.conf.template".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/kitty/noctalia.conf.template";
    configFile."kitty/themes/lume.conf".source = flake-inputs.lume-theme + "/terminals/kitty/lume.conf";
    configFile."kitty/theme.conf".text = ''
      include themes/lume.conf
    '';
  };
}
