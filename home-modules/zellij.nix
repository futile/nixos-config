{
  config,
  pkgs,
  thisFlakePath,
  ...
}:
{
  # only config file for now
  xdg = {
    enable = true;
    # symlink directly to this repo, for easier iteration/changes
    configFile."zellij/config.kdl".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/zellij/config.kdl";
  };
}
