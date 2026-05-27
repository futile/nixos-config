{
  config,
  flake-inputs,
  pkgs,
  system,
  thisFlakePath,
  ...
}:
{
  home.packages = with pkgs; [
    flake-inputs.codebase-memory-mcp.packages.${system}.default
    my-custom-packages.headroom
    my-custom-packages.context-mode
    rtk
  ];

  home.file.".codex/hooks.json".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/codex/hooks.json";

  systemd.user.services.headroom = pkgs.lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Headroom API proxy for Codex";
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.my-custom-packages.headroom}/bin/headroom proxy --port 8787";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
