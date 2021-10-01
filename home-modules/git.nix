{ inputs, ... }:
{ config, pkgs, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.gitAndTools.gitFull;
    userName = "Felix Rath";

    extraConfig = {
      init = {
        defaultBranch = "main";
      };
      core = {
        editor = "vim";
      };
      pull = {
        ff = "only";
      };
      rebase = {
        autoStash = "true";
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

  home.packages = [pkgs.git-absorb];
}
