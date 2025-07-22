{
  config,
  pkgs,
  thisFlakePath,
  ...
}:
let
  configDirPath =
    if pkgs.stdenv.isLinux then ".config/gitbutler" else "Library/Application Support/gitbutler";
in
{
  home.packages = with pkgs; [
    gitbutler
  ];

  # link the full directory, because otherwise gitbutler replaces the symlink
  # with a regular file when writing out `settings.json` (>.>)
  home.file."${configDirPath}".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/gitbutler";
}
