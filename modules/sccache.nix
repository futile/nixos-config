{
  lib,
  config,
  ...
}:
let
  cfg = config.my.rustSccache;
  withRustSccache =
    final: name: package:
    let
      wrapped = package.overrideAttrs (oldAttrs: {
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
          final.sccache
        ];
        env = (oldAttrs.env or { }) // {
          RUSTC_WRAPPER = lib.getExe final.sccache;
          SCCACHE_DIR = cfg.cacheDir;
        };
        preBuild = ''
          mkdir -p "$SCCACHE_DIR"
        ''
        + (oldAttrs.preBuild or "");
      });
    in
    if cfg.trace then builtins.trace "with rust sccache: ${name}" wrapped else wrapped;
  rust-sccache-overlay =
    final: prev:
    lib.genAttrs cfg.packageNames (packageName: withRustSccache final packageName prev.${packageName})
    // lib.optionalAttrs (cfg.customPackageNames != [ ]) {
      my-custom-packages =
        (prev.my-custom-packages or { })
        // lib.genAttrs cfg.customPackageNames (
          packageName:
          withRustSccache final "my-custom-packages.${packageName}" prev.my-custom-packages.${packageName}
        );
    };
in
{
  options.my.rustSccache = {
    enable = lib.mkEnableOption "sccache for selected local Rust package builds";

    cacheDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/cache/ccache/sccache";
      description = "Directory used by sccache inside Nix build sandboxes.";
    };

    packageNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Top-level nixpkgs package attributes to build with sccache.";
    };

    customPackageNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "pkgs.my-custom-packages attributes to build with sccache.";
    };

    trace = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Trace package attributes that are wrapped with sccache.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings.extra-sandbox-paths = [ cfg.cacheDir ];

    systemd.tmpfiles.rules = [
      "d ${cfg.cacheDir} 0770 root nixbld -"
    ];

    nixpkgs.overlays = lib.mkAfter [
      rust-sccache-overlay
    ];
  };
}
