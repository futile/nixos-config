{
  config,
  thisFlakePath,
  ...
}:
{
  home.file.".agents".source = config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/agents";
}
