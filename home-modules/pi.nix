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
  upstreamExtensions = "${flake-inputs.fdietze-dotfiles}/modules/home-manager/profiles/ai-agents/pi-extensions";
  patchedSubagents = pkgs.runCommand "fdietze-pi-subagents" { } ''
    mkdir -p "$out"
    cp -R "${upstreamExtensions}/subagents/." "$out/"
    chmod -R u+w "$out"

    patch -d "$out" -p1 < ${../patches/fdietze-pi-subagents-child-extensions.patch}
    substituteInPlace "$out/index.ts" \
      --replace-fail '@CONTEXT_PRUNE_PATH@' "${upstreamExtensions}/context-prune"
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

      ".pi/agent/extensions/subagents".source = patchedSubagents;
      ".pi/agent/extensions/context-prune".source = "${upstreamExtensions}/context-prune";
    };

    home.sessionVariables = {
      WEB_SEARCH_PROVIDER = "searxng";
      SEARXNG_URL = "http://127.0.0.1:8888";
    };
  };
}
