{
  config,
  pkgs,
  thisFlakePath,
  ...
}:
{
  home.packages = with pkgs; [
    my-custom-packages.context-mode
    rtk
  ];

  home.file.".codex/hooks.json".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/codex/hooks.json";
}
