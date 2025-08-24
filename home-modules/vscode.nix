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
    extraWrapProgramArgs = [
      "--set"
      "BASH_ENV"
      ''"${thisFlakePath}/scripts/bash_env_direnv.sh"''
    ];
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

  # fix for bash & direnv
  # ref: https://github.com/direnv/direnv-vscode/issues/561#issuecomment-3053744254
  # ref: https://github.com/HugoHakem/nix-os.config/pull/21/files
  programs.bash.initExtra = pkgs.lib.mkOrder 2000 ''
    # This is a workaround to make direnv work with VS Code's integrated terminal
    # when using the direnv extension, by making sure to reload
    # the environment the first time terminal is opened.
    #
    # See: 
    # - author problem statement: https://github.com/direnv/direnv-vscode/issues/561#issuecomment-1837462994
    # - zsh work around: https://github.com/direnv/direnv-vscode/issues/561#issuecomment-1991534148
    # - fish work around: https://github.com/direnv/direnv-vscode/issues/561#issuecomment-2310756248
    # - bash work around (requiring .envrc tinkering): https://github.com/direnv/direnv-vscode/issues/561#issuecomment-2694803523
    # 
    # Solution inspired by `fish`: 
    #
    # The variable VSCODE_INJECTION is apparently set by VS Code itself, and this is how
    # we can detect if we're running inside the VS Code terminal or not.
    # In bash, eval "$PROMPT_COMMAND" helps direnv to notice directory change and trigger envrc loading.

    if [[ -n "$VSCODE_INJECTION" && -z "$VSCODE_TERMINAL_DIRENV_LOADED" && -f .envrc ]]; then
      cd .. && eval "$PROMPT_COMMAND" && cd ~- && eval "$PROMPT_COMMAND"
      export VSCODE_TERMINAL_DIRENV_LOADED=1
    fi
  '';
}
