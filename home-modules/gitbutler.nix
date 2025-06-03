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

  # link the full directory, because otherwise gitbutler replaces the symlink
  # with a regular file when writing out `settings.json` (>.>)
  home.file."Library/Application Support/gitbutler".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/gitbutler";

  # let's try this out a bit
  programs.fish.shellAbbrs = {
    nn = "jj";
  };
}
