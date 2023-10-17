{ config, pkgs, ... }:
let
  my-neovide = pkgs.symlinkJoin {
    name = "neovide";
    paths = [ pkgs.unstable.neovide ];
    buildInputs = [ pkgs.makeWrapper ];
    # start neovide with `--multigrid --frame=none --maximized`
    # `home.sessionVariables` aren't picked up by graphical environments :(
    postBuild = ''
      wrapProgram $out/bin/neovide \
        --set-default NEOVIDE_MULTIGRID "1" \
        --set-default NEOVIDE_MAXIMIZED "1"
    '';
  };
in
{
  programs.neovim = {
    enable = true;
    extraPackages = pkgs.lib.my.editorTools ++ [ pkgs.xsel ];

    # dunno how to do this together with lazyvim :/
    # extraLuaConfig = ''
    #   -- bootstrap lazy.nvim, LazyVim and your plugins
    #   require("config.lazy")
    # '';
    # plugins = [
    #   (builtins.trace pkgs.vimPlugins.nvim-treesitter.withAllGrammars.type pkgs.vimPlugins.nvim-treesitter.withAllGrammars)
    # ];
  };

  home.packages = [ my-neovide ];

  xdg = {
    enable = true;
    configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nixos/dotfiles/nvim";
  };
}
