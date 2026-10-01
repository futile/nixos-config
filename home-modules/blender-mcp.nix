{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.blenderMcp;
in
{
  options.my.blenderMcp = {
    enable = lib.mkEnableOption "the Blender MCP server and its matching add-on";
    package = lib.mkPackageOption pkgs.my-custom-packages "mcp-for-blender" { };
    blenderPackage = lib.mkPackageOption pkgs "blender" { };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      cfg.blenderPackage
    ];

    # Installation is declarative; enable "MCP for Blender" once in Preferences.
    xdg.configFile."blender/${lib.versions.majorMinor cfg.blenderPackage.version}/scripts/addons/blender_mcp.py".source =
      "${cfg.package}/share/blender/addons/blender_mcp.py";
  };
}
