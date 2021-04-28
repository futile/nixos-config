{ inputs }: 
{ config, pkgs, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.gitAndTools.gitFull;
    userName = "Felix Rath";

    extraConfig = {
      core = {
        editor = "vim";
      };
      pull = {
        ff = "only";
      };
    };

    delta = {
      enable = true;
      options = {
        syntax-theme = "GitHub";
      };
    };

    lfs.enable = true;
  };
}