{
  config,
  thisFlakePath,
  ...
}:
{
  home.file.".agents/skills/find-skills".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/agents/skills/find-skills";

  home.file.".agents/skills/spark-delegate".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/agents/skills/spark-delegate";
}
