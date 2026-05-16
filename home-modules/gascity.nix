{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.gascity;

  runtimeDependencies = with pkgs; [
    tmux
    jq
    git
    dolt
    util-linux
  ];

  installedPackages = [
    cfg.package
  ]
  ++ runtimeDependencies
  ++ lib.optionals cfg.includeBeads [ pkgs.beads ];

  supervisorPath = lib.makeBinPath ([ pkgs.systemd ] ++ installedPackages);
  supervisorExtraPath = lib.concatStringsSep ":" cfg.supervisor.extraPath;
  supervisorFullPath =
    supervisorPath + lib.optionalString (supervisorExtraPath != "") ":${supervisorExtraPath}";
  supervisorHome = "${config.home.homeDirectory}/.gc";
in
{
  options.my.gascity = {
    enable = lib.mkEnableOption "Gas City CLI and runtime dependencies";

    package = lib.mkPackageOption pkgs.my-custom-packages "gascity" { };

    includeBeads = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install the Beads CLI through Home Manager. Leave disabled when `bd` is
        managed separately, for example with `nix profile install`.
      '';
    };

    supervisor = {
      installOnActivation = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Run `gc supervisor install` during Home Manager activation. Gas City
          compares the rendered unit with the installed unit and may reload,
          enable, start, or warm-refresh the user systemd service.
        '';
      };

      extraPath = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "${config.home.homeDirectory}/.nix-profile/bin" ];
        description = ''
          Extra PATH entries captured by `gc supervisor install`. This is useful
          for dependencies managed outside Home Manager, such as a profile
          installed Beads CLI.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = installedPackages;

    home.activation.gascitySupervisorInstall = lib.mkIf cfg.supervisor.installOnActivation (
      lib.hm.dag.entryAfter [ "installPackages" ] ''
        desired_path=${lib.escapeShellArg supervisorFullPath}
        supervisor_home=${lib.escapeShellArg supervisorHome}
        systemctl=${lib.escapeShellArg "${pkgs.systemd}/bin/systemctl"}
        xdg_runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

        if ! PATH="$desired_path" command -v bd >/dev/null 2>&1; then
          warnEcho "Gas City runtime dependency 'bd' was not found in the supervisor PATH."
        fi

        systemd_status=$(env XDG_RUNTIME_DIR="$xdg_runtime_dir" "$systemctl" --user is-system-running 2>&1 || true)

        if [[ "$systemd_status" == "running" || "$systemd_status" == "degraded" ]]; then
          run install -d -m 700 "$supervisor_home"

          # Let Gas City compare the full rendered unit and perform the
          # daemon-reload/enable/start or warm-refresh sequence it owns.
          run env XDG_RUNTIME_DIR="$xdg_runtime_dir" PATH="$desired_path" ${lib.getExe cfg.package} supervisor install
        else
          warnEcho "User systemd daemon not running. Skipping Gas City supervisor install."
        fi
      ''
    );
  };
}
