{
  config,
  flake-inputs,
  lib,
  pkgs,
  thisFlakePath,
  ...
}:
let
  cfg = config.my.pi;
  patchedInfiniteContext = pkgs.runCommand "pi-infinite-context" { } ''
    mkdir -p "$out"
    cp -R "${flake-inputs.pi-infinite-context}/." "$out/"
    chmod -R u+w "$out"

    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/pi-infinite-context-enable-nudges.patch}
  '';
  patchedActorSubagents = pkgs.runCommand "pi-actor-subagents" { } ''
    mkdir -p "$out"
    cp -R "${flake-inputs.pi-actor-subagents}/." "$out/"
    chmod -R u+w "$out"

    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/pi-actor-subagents-local.patch}
  '';
in
{
  options.my.pi = {
    enable = lib.mkEnableOption "managed Pi agent configuration";

    settingsJson = lib.mkOption {
      type = lib.types.str;
      description = "Host-specific Pi settings.json source path.";
    };

    mcpJson = lib.mkOption {
      type = lib.types.str;
      description = "Host-specific Pi MCP configuration source path.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Keep the Pi CLI itself in `nix profile`; Home Manager owns only its configuration.
    home.file = {
      ".pi/agent/AGENTS.md".source =
        config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/codex/AGENTS.md";

      ".pi/agent/settings.json" = {
        source = config.lib.file.mkOutOfStoreSymlink cfg.settingsJson;
        force = true;
      };

      ".pi/agent/mcp.json" = {
        source = config.lib.file.mkOutOfStoreSymlink cfg.mcpJson;
        force = true;
      };

      ".pi/agent/extensions/infinite-context".source =
        "${patchedInfiniteContext}/extensions/infinite-context";
      ".pi/agent/extensions/infinite-context.json".text = builtins.toJSON {
        enableNudges = false;
      };
      ".pi/agent/extensions/actor-subagents".source =
        "${patchedActorSubagents}/extensions/actor-subagents";
      ".pi/agent/actor-subagents/settings.json".text = builtins.toJSON {
        maxAgents = 8;
        maxSpawnDepth = 3;
        childExtensions = [
          "npm:pi-mcp-adapter@2.17.0"
          "npm:@juicesharp/rpiv-web-tools@2.3.1"
          "git:github.com/DietrichGebert/ponytail"
          "${config.home.homeDirectory}/.pi/agent/extensions/infinite-context"
          "${config.home.homeDirectory}/.pi/agent/extensions/context-pressure"
          "${config.home.homeDirectory}/.pi/agent/extensions/codex-fast"
        ];
      };
      ".pi/agent/extensions/context-pressure".source =
        config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/pi/extensions/context-pressure";
      ".pi/agent/extensions/codex-fast".source =
        config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/pi/extensions/codex-fast";
    };

    home.sessionVariables = {
      WEB_SEARCH_PROVIDER = "searxng";
      SEARXNG_URL = "http://127.0.0.1:8888";
    };
  };
}
