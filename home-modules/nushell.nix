{
  config,
  pkgs,
  thisFlakePath,
  ...
}:
{
  programs.nushell = {
    enable = true;
    package = pkgs.nushell;

    # We want the generate config files to be used (they are also written to
    # by zoxide, direnv, etc.'s configs, but we also want our shared files to
    # be sourced. Paths can't be relative there atm., see some existing github issue.
    extraConfig = "source ${config.xdg.configHome}/nushell/shared_config.nu";
    extraEnv = "source ${config.xdg.configHome}/nushell/shared_env.nu";
  };

  xdg = {
    enable = true;
    configFile."nushell/shared_config.nu".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/nushell/shared_config.nu";
    configFile."nushell/shared_env.nu".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/nushell/shared_env.nu";
  };

  programs.zoxide.enableNushellIntegration = true;
}
