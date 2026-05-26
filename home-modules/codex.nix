{
  config,
  lib,
  thisFlakePath,
  ...
}:
let
  cfg = config.my.codex;
in
{
  options.my.codex.configToml = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Optional host-specific Codex config.toml source path.";
  };

  config = lib.mkMerge [
    {
      # Keep the Codex CLI itself in `nix profile` for faster updates than nixpkgs/Home Manager.

      home.file.".codex/AGENTS.md".source =
        config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/codex/AGENTS.md";
      home.file.".codex/agents".source =
        config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/codex/agents";
    }

    (lib.mkIf (cfg.configToml != null) {
      home.file.".codex/config.toml" = {
        source = config.lib.file.mkOutOfStoreSymlink cfg.configToml;
        force = true;
      };
    })
  ];
}
