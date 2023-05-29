{ config, lib, pkgs, thisFlakePath, ... }: {
  programs.home-manager.enable = true;

  home = {
    file = {
      "bin".source = config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/bin";
    };

    sessionPath = [ "$HOME/bin" ];
  };
}
