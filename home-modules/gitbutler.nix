{
  config,
  pkgs,
  thisFlakePath,
  ...
}:
{
  home.packages = with pkgs; [
    gitbutler
  ];

  home.file."Library/Application Support/gitbutler/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/gitbutler/settings.json";

  # let's try this out a bit
  programs.fish.shellAbbrs = {
    nn = "jj";
  };
}
