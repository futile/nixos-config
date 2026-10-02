# Blender MCP

`mcp-for-blender` is a native Nix Python package pinned to PyPI 2.1.3. It supplies
both the MCP executable and the matching Blender add-on. No `uvx` or runtime
package downloads are needed.

On `nixos-work`, `my.blenderMcp` installs the server and the existing
`nixpkgs-unstable.blender` package. Home Manager links the add-on into
`$XDG_CONFIG_HOME/blender/<major.minor>/scripts/addons/blender_mcp.py`, deriving
the directory version from that Blender package. Pi launches the packaged MCP
server lazily.

## After applying the configuration

1. Restart Blender, open **Preferences → Add-ons**, search for **MCP for
   Blender**, and enable it. Save preferences if automatic saving is disabled.
2. The add-on normally starts its socket server automatically. Its controls are
   in the 3D View sidebar (press **N**), under **MCP for Blender**. Check that it
   is running on port **9876**.
3. Restart Pi to reload its MCP configuration.

The MCP server uses stdio to talk to Pi and a loopback TCP connection to Blender.
No firewall port needs opening. Only enable this add-on for trusted MCP clients:
it permits executing Python inside Blender and is not a sandbox.

Telemetry is disabled by the packaged executable. The add-on's automatic and
manual self-updaters are disabled; update the Nix package instead. Do not use
upstream's `setup` or `install-addon` commands for this Home Manager installation:
they imperatively edit configuration or copy files outside Nix management.

For another Linux Home Manager host, import `home-modules/blender-mcp.nix`, set
`my.blenderMcp.enable = true`, and optionally choose
`my.blenderMcp.blenderPackage`. Configure its MCP client to execute
`mcp-for-blender` directly.

## Viewport screenshots

Pi reads the server definition from `~/.pi/agent/mcp-adapter.json` with
`pi-mcp-adapter` 4.0.0. Its automatic browser viewer can still block the
screenshot request on Linux while waiting for the browser opener to exit.
For inline screenshots without opening a browser, quit Pi and continue with:

```sh
MCP_UI_VIEWER=none pi -c
```

This variable belongs to Pi, not the Blender MCP server's `env`. It suppresses
automatic MCP UI windows for that process; screenshots still reach the model.
The upgrade fixes app-only viewport polling triggering unwanted model turns,
but does not fix the browser-opener wait. Browser behavior is unchanged by the
repository configuration.

## Package checks

```sh
nice -n 19 nix build .#mcp-for-blender --no-link
nice -n 19 nix run .#mcp-for-blender -- --help
```

The package build runs upstream's tests plus regression checks that its Nix
add-on cannot start update checks or overwrite its installation, and MCP update
guidance points to Nix rather than `uvx`. No live system or Blender preferences
are changed by building.
