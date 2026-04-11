{
  config,
  thisFlakePath,
  ...
}:
{
  # Keep the Codex CLI itself in `nix profile` for faster updates than nixpkgs/Home Manager.
  home.file.".codex/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/codex/config.toml";
}
