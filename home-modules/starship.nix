{ config, pkgs, thisFlakePath, ... }:

{
  # starship prompt: https://starship.rs
  programs.starship = {
    enable = true;
  };

  xdg = {
    enable = true;

    # symlink `starship.toml` directly into this repo
    configFile."starship.toml".source = config.lib.file.mkOutOfStoreSymlink
      "${thisFlakePath}/dotfiles/starship.toml";
  };
}
