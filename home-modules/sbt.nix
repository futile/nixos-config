{
  config,
  pkgs,
  thisFlakePath,
  ...
}:
{
  home = {
    packages = with pkgs; [ sbt ];
    file = {
      ".sbt/1.0/global.sbt".source =
        config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/sbt-1.0/global.sbt";
      ".sbt/1.0/plugins/plugins.sbt".source =
        config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/sbt-1.0/plugins/plugins.sbt";
    };
  };
}
