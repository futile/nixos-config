{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    jujutsu
    difftastic

    # TUI, really good
    lazyjj

    # nice gui for jj, https://github.com/gulbanana/gg
    gg-jj
  ];

  xdg = {
    enable = true;
    configFile."jj".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dotfiles/jj/";
  };

  # let's try this out a bit
  programs.fish.shellAbbrs = {
    nn = "jj";
  };
}
