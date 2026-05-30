{
  config,
  lib,
  ...
}:
let
  cfg = config.my.serena;
in
{
  options.my.serena = {
    configYml = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional host-specific Serena serena_config.yml source path.";
    };

    globalMemoriesDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional host-specific Serena global memories source directory.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.configYml != null) {
      home.file.".serena/serena_config.yml" = {
        source = config.lib.file.mkOutOfStoreSymlink cfg.configYml;
        force = true;
      };
    })

    (lib.mkIf (cfg.globalMemoriesDir != null) {
      home.file.".serena/memories/global" = {
        source = config.lib.file.mkOutOfStoreSymlink cfg.globalMemoriesDir;
        force = true;
      };
    })
  ];
}
