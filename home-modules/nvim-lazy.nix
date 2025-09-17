{
  config,
  pkgs,
  thisFlakePath,
  ...
}:
let
  my-neovide = pkgs.symlinkJoin {
    name = "neovide";
    paths = [ pkgs.neovide ];
    buildInputs = [ pkgs.makeWrapper ];
    # start neovide with `--fork --frame=none --maximized`
    # `home.sessionVariables` aren't picked up by graphical environments :(
    postBuild = ''
      wrapProgram $out/bin/neovide \
        --set-default NEOVIDE_FRAME "none" \
        --set-default NEOVIDE_FORK "1" \
        --set-default NEOVIDE_MAXIMIZED "1"
    '';
  };
in
{
  programs.neovim = {
    enable = true;
    extraPackages = pkgs.lib.my.editorTools ++ (pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.xsel ]);

    extraLuaPackages = luaPkgs: with luaPkgs; [ sqlite ];

    # dunno how to do this together with lazyvim :/
    # extraLuaConfig = ''
    #   -- bootstrap lazy.nvim, LazyVim and your plugins
    #   require("config.lazy")
    # '';
    # plugins = [
    #   (builtins.trace pkgs.vimPlugins.nvim-treesitter.withAllGrammars.type pkgs.vimPlugins.nvim-treesitter.withAllGrammars)
    # ];
  };

  home.packages = [
    my-neovide

    # required since LazyVim 15
    pkgs.tree-sitter
  ];

  xdg = {
    enable = true;
    configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/nvim";
  };

  # home.file = {
  #   ".cache/nvim/codeium/bin/1.2.90/language_server_linux_x64".source = "${pkgs.codeium}/bin/codeium_language_server";
  # };
}
