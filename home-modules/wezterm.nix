{ config, pkgs, flake-inputs, thisFlakePath, ... }:

{
  # rolling wezterm by hand, as I don't like the upstream home-manager module
  home.packages = with pkgs.unstable; [
    wezterm
    xsel # for system clipboard, because wezterm ignores clipboard escape codes for security reasons
  ];

  xdg = {
    enable = true;

    # symlink directly to this repo, for easier iteration/changes
    configFile."wezterm/wezterm.lua".source =
      config.lib.file.mkOutOfStoreSymlink
        "${thisFlakePath}/dotfiles/wezterm/wezterm.lua";
    configFile."wezterm/colors/everforest.toml".source =
      flake-inputs.wezterm-everforest + "/everforest.toml";
    configFile."wezterm/colors/embark.toml".source =
      flake-inputs.wezterm-embark + "/colors/embark.toml";
  };
}
