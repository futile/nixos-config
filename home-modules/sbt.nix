{ config, pkgs, thisFlakePath, ... }: {
  home = {
    packages = with pkgs.unstable; [ sbt ];
    file.".sbt/1.0/global.sbt".source = config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/sbt-1.0/global.sbt";
  };
}
