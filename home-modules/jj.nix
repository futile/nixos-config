{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    jujutsu
    difftastic

    # gg broken until https://nixpk.gs/pr-tracker.html?pr=439100 is in nixos-unstable
    # gg-jj # nice gui for jj, https://github.com/gulbanana/gg
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
