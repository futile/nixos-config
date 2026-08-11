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

    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/fdietze-pi-subagents-bind-errors.patch}
    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/fdietze-pi-subagents-model-routing.patch}
    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/fdietze-pi-subagents-engine-reset.patch}
    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/fdietze-pi-subagents-activity.patch}
    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/fdietze-pi-subagents-fast.patch}
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
      ".pi/agent/extensions/codex-fast".source =
        config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/pi/extensions/codex-fast";
    };

    xdg.configFile."pi/subagents/child-extensions.json".text = builtins.toJSON {
      extensions = [
        "npm:pi-mcp-adapter@2.17.0"
        "npm:@juicesharp/rpiv-web-tools@2.3.1"
        "git:github.com/DietrichGebert/ponytail"
        "${config.home.homeDirectory}/.pi/agent/extensions/context-prune"
        "${config.home.homeDirectory}/.pi/agent/extensions/codex-fast"
      ];
    };

    home.sessionVariables = {
      WEB_SEARCH_PROVIDER = "searxng";
      SEARXNG_URL = "http://127.0.0.1:8888";
    };
  };
}
