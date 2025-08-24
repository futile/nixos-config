{
  config,
  pkgs,
  flake-inputs,
  thisFlakePath,
  ...
}:
let
  vscode-fhs-with-editor-tools = pkgs.lib.my.mkWrappedWithDeps {
    pkg = pkgs.vscode.fhs;
    pathsToWrap = [
      "bin/code"
    ];
    # extraWrapProgramArgs = [
    #   "--set"
    #   "DOOMDIR"
    #   ''"${config.home.sessionVariables.DOOMDIR}"''
    #   "--set"
    #   "DOOMLOCALDIR"
    #   ''"${config.home.sessionVariables.DOOMLOCALDIR}"''
    # ];
    prefix-deps = with pkgs; [
      ripgrep
      findutils
      fd
    ];
    suffix-deps = pkgs.lib.my.editorTools;
  };
in
{
  programs.vscode = {
    enable = true;
    package = vscode-fhs-with-editor-tools;
  };

  xdg = {
    enable = true;

    # symlink directly to this repo, for easier iteration/changes
    configFile."Code/User/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/vscode/settings.json";
  };
}
