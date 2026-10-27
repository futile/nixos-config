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

    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/pi-infinite-context-restart.patch}
  '';
  patchedActorSubagents = pkgs.runCommand "pi-actor-subagents" { } ''
    mkdir -p "$out"
    cp -R "${flake-inputs.pi-actor-subagents}/." "$out/"
    chmod -R u+w "$out"

    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/pi-actor-subagents-local.patch}
    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/pi-actor-subagents-restart.patch}
    # bash-async jobs signal: swarm-line total, kill report, terminal progress while jobs run.
    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/pi-actor-subagents-background-jobs.patch}
  '';
  # npm build output; the patch translates its Korean UI strings to English.
  patchedCodexImageGen = pkgs.runCommand "pi-codex-image-gen" { } ''
    mkdir -p "$out"
    tar -xzf ${
      pkgs.fetchurl {
        url = "https://registry.npmjs.org/@buyong/pi-codex-image-gen/-/pi-codex-image-gen-0.3.1.tgz";
        hash = "sha256-UgTgLUGSloJKAtxPMBgxY3X51KjjTji/+Cw3O26MpcY=";
      }
    } -C "$out" --strip-components=1
    chmod -R u+w "$out"

    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/pi-codex-image-gen-english.patch}
  '';
in
{
  options.my.pi = {
    enable = lib.mkEnableOption "managed Pi agent configuration";

    settingsJson = lib.mkOption {
      type = lib.types.str;
      description = "Host-specific Pi settings.json source path.";
    };

    mcpAdapterJson = lib.mkOption {
      type = lib.types.str;
      description = "Host-specific pi-mcp-adapter configuration source path.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Keep the Pi CLI itself in `nix profile`; the launcher pins it per invocation.
    home.packages = [
      (pkgs.writeShellApplication {
        name = "pi-restartable";
        text = ''
          exec ${pkgs.python3}/bin/python3 ${../bin/pi-restartable} "$@"
        '';
      })
    ];
    programs.fish.shellAliases.pi = "pi-restartable";

    home.file = {
      ".pi/agent/AGENTS.md".source =
        config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/codex/AGENTS.md";

      ".pi/agent/settings.json" = {
        source = config.lib.file.mkOutOfStoreSymlink cfg.settingsJson;
        force = true;
      };

      ".pi/agent/mcp-adapter.json" = {
        source = config.lib.file.mkOutOfStoreSymlink cfg.mcpAdapterJson;
        force = true;
      };

      ".pi/agent/extensions/infinite-context".source =
        "${patchedInfiniteContext}/extensions/infinite-context";
      # context-pressure owns reminders; upstream only nudges once the window is full.
      ".pi/agent/infinite-context/settings.json".text = builtins.toJSON {
        nudgeAtTokens = 1000000000;
        nudgeAtPercent = 100;
      };
      # Loaded as a local package from settings.json (its manifest also declares skills).
      ".pi/agent/packages/pi-codex-image-gen".source = patchedCodexImageGen;
      ".pi/agent/extensions/actor-subagents".source =
        "${patchedActorSubagents}/extensions/actor-subagents";
      ".pi/agent/actor-subagents/settings.json".text = builtins.toJSON {
        maxAgents = 16;
        maxSpawnDepth = 3;
        childExtensions = [
          "npm:pi-mcp-adapter@5.0.0"
          "npm:@juicesharp/rpiv-web-tools@2.12.0"
          "git:github.com/DietrichGebert/ponytail"
          "${config.home.homeDirectory}/.pi/agent/extensions/infinite-context"
          "${config.home.homeDirectory}/.pi/agent/extensions/context-pressure"
          "${config.home.homeDirectory}/.pi/agent/extensions/codex-fast"
          "${config.home.homeDirectory}/.pi/agent/extensions/bash-async"
          "${config.home.homeDirectory}/.pi/agent/packages/pi-codex-image-gen"
        ];
        # Children's other statuses (mcp, ponytail, ...) are noise in the roster.
        childExtensionStatusKeys = [ "bash-async" ];
      };
      # Async background bash jobs (fork: /reload keeps jobs, ⏳N footer status + pi.events signal
      # for actor-subagents, command display); its own tests live in the fork.
      ".pi/agent/extensions/bash-async".source = flake-inputs.pi-bash-async;
      ".pi/agent/extensions/pi-restart-in-dir".source =
        config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/pi/extensions/pi-restart-in-dir";
      ".pi/agent/extensions/context-pressure".source =
        config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/pi/extensions/context-pressure";
      ".pi/agent/extensions/codex-fast".source =
        config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/pi/extensions/codex-fast";
      ".pi/agent/extensions/static-working-indicator".source =
        config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/pi/extensions/static-working-indicator";
    };

    home.sessionVariables = {
      WEB_SEARCH_PROVIDER = "searxng";
      SEARXNG_URL = "http://127.0.0.1:8888";
    };
  };
}
