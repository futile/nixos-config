{
  config,
  thisFlakePath,
  ...
}:
{
  # Keep the Codex CLI itself in `nix profile` for faster updates than nixpkgs/Home Manager.
  # 2026-04-11 Codex adds "trusted project paths" to the file, which are machine-specific, so can't share the file :/
  # home.file.".codex/config.toml".source =
  #   config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/codex/config.toml";
}
