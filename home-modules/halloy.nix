{
  config,
  pkgs,
  thisFlakePath,
  ...
}:
{
  home.packages = [ pkgs.halloy ];

  xdg = {
    enable = true;
    configFile."halloy/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/halloy/config.toml";
  };
}
