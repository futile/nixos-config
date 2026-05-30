{
  config,
  flake-inputs,
  pkgs,
  system,
  thisFlakePath,
  ...
}:
let
  # See docs/codex-token-optimization-stack.md#headroom-evaluation.
  # Keep the service definition available for future experiments, but do not
  # install or start Headroom for normal Codex use.
  enableHeadroomProxy = false;
in
{
  home.packages = with pkgs; [
    flake-inputs.codebase-memory-mcp.packages.${system}.default
    my-custom-packages.context-mode
    my-custom-packages.serena
    rtk
  ];

  home.file.".codex/hooks.json".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/codex/hooks.json";

  systemd.user.services.headroom = pkgs.lib.mkIf (pkgs.stdenv.isLinux && enableHeadroomProxy) {
    Unit = {
      Description = "Headroom API proxy for Codex";
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.my-custom-packages.headroom}/bin/headroom proxy --port 8787 --mode token --limit-concurrency 4 --retry-max-attempts 1 --no-telemetry";
      Environment = [
        "HEADROOM_COMPRESSION_MAX_WORKERS=1"
        "HEADROOM_COMPRESS_WORKERS=1"
        "HEADROOM_KOMPRESS_MAX_CONCURRENT=1"
        "HEADROOM_WS_COMPRESSION_FAIL_THRESHOLD_BYTES=1048576"
        "HEADROOM_WS_FAIL_OPEN_ON_COMPRESSION_FAILURE=1"
        "OMP_NUM_THREADS=1"
        "ORT_NUM_THREADS=1"
        "RAYON_NUM_THREADS=1"
      ];
      CPUQuota = "200%";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
