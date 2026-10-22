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
    # Upstream: https://github.com/fdietze/pi-actor-subagents/pull/6
    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/pi-actor-subagents-pause-refused-turn.patch}
    # Roster/list_subagents/kill show bash-async jobs (pairs with pi-bash-async-jobs-signal.patch).
    patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/pi-actor-subagents-background-jobs.patch}
  '';
  # Async background bash jobs; patched so /reload hands running jobs over instead of killing them
  # and so running jobs are announced to actor-subagents and the statusline.
  patchedBashAsync =
    pkgs.runCommand "pi-bash-async-0.4.1"
      {
        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/@ryan_nookpi/pi-extension-bash-async/-/pi-extension-bash-async-0.4.1.tgz";
          hash = "sha512-QxgpSvMXFKIr9hqG1+C2qTfsp8nL5X2mLCe4CjjMUf7Fzm+YocLqQOBgPj6V4UnfUHdLD+DQhBFA8cpvjO0LXw==";
        };
        nativeBuildInputs = [ pkgs.nodejs ];
      }
      ''
        mkdir -p "$out"
        tar -xzf "$src" --strip-components=1 -C "$out"
        chmod -R u+w "$out"

        patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/pi-bash-async-reload.patch}
        # Announces unsettled jobs on pi.events and as the "bash-async" footer status (⏳/⏳N).
        patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/pi-bash-async-jobs-signal.patch}
        # Shows the command in the call row and widget; default title = whole command, not its first word.
        patch -d "$out" -p1 --fuzz=0 --no-backup-if-mismatch < ${../patches/pi-bash-async-command-display.patch}
        BASH_ASYNC_DIR="$out" HOME="$TMPDIR" node --experimental-transform-types --no-warnings \
          --import ${../tests/pi-bash-async}/register.mjs --test \
          ${../tests/pi-bash-async}/reload.test.mjs ${../tests/pi-bash-async}/jobs-signal.test.mjs \
          ${../tests/pi-bash-async}/command-display.test.mjs
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
        ];
      };
      ".pi/agent/extensions/bash-async".source = patchedBashAsync;
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
