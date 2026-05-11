{
  config,
  lib,
  pkgs,
  thisFlakePath,
  ...
}:
let
  cfg = config.my.nixProfileSnapshot;

  # Mirror imperative `nix profile` state into this repo for review/history.
  # The systemd path watches the profile symlink directory because profile
  # updates create a new generation link instead of editing a manifest in place.
  snapshotScript = pkgs.writeShellApplication {
    name = "snapshot-nix-profile";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.nix
    ];
    text = ''
      set -euo pipefail

      profile_name=${lib.escapeShellArg cfg.profileName}
      profile_path=${lib.escapeShellArg cfg.profilePath}
      host_name=${lib.escapeShellArg cfg.hostName}
      repo_path=${lib.escapeShellArg cfg.repoPath}

      if [[ ! -e "$profile_path" ]]; then
        echo "profile path does not exist: $profile_path" >&2
        exit 1
      fi

      out_dir="$repo_path/dotfiles/nix-profiles/$host_name"
      out_file="$out_dir/$profile_name.json"

      mkdir -p "$out_dir"

      tmp="$(mktemp "$out_file.tmp.XXXXXX")"
      trap 'rm -f "$tmp"' EXIT

      nix profile list --profile "$profile_path" --json | jq --sort-keys . > "$tmp"
      mv "$tmp" "$out_file"

      trap - EXIT
    '';
  };
in
{
  options.my.nixProfileSnapshot = {
    enable = lib.mkEnableOption "automatic snapshots of nix profile state";

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "nixos-work";
      description = ''
        Host directory name under dotfiles/nix-profiles. Set this explicitly so
        snapshot paths stay aligned with the repository's host names.
      '';
    };

    profileName = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = "Profile snapshot filename, without the .json suffix.";
    };

    profilePath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.nix-profile";
      description = "Profile path passed to nix profile list.";
    };

    watchDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/nix/var/nix/profiles/per-user/${config.home.username}";
      description = ''
        Directory watched by systemd. nix profile updates replace profile
        symlinks here; the manifest inside the store output does not change.
      '';
    };

    repoPath = lib.mkOption {
      type = lib.types.str;
      default = thisFlakePath;
      description = "Repository checkout where profile JSON snapshots are written.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.hostName != null;
        message = "my.nixProfileSnapshot.hostName must be set when nix profile snapshots are enabled.";
      }
    ];

    systemd.user.services.snapshot-nix-profile = {
      Unit = {
        Description = "Snapshot nix profile state into nixos repo";
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${snapshotScript}/bin/snapshot-nix-profile";
      };
    };

    systemd.user.paths.snapshot-nix-profile = {
      Unit = {
        Description = "Watch nix profile generation changes";
      };

      Path = {
        PathChanged = cfg.watchDirectory;
        Unit = "snapshot-nix-profile.service";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
