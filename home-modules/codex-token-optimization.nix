{
  config,
  flake-inputs,
  pkgs,
  system,
  thisFlakePath,
  ...
}:
{
  home.packages = with pkgs; [
    flake-inputs.codebase-memory-mcp.packages.${system}.default
    my-custom-packages.context-mode
    rtk
  ];

  home.file.".codex/hooks.json".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/codex/hooks.json";
}
