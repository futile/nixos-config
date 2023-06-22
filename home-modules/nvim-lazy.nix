{ config, pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    extraPackages = pkgs.lib.my.editorTools ++ [ pkgs.xsel ];
  };

  home.packages = [ pkgs.unstable.neovide ];

  xdg = {
    enable = true;
    configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nixos/dotfiles/nvim";
  };
}
