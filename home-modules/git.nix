{ config, pkgs, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.gitAndTools.gitFull;
    userName = "Felix Rath";

    extraConfig = {
      core = {
        editor = "nvim";
        autocrlf = "input";
      };
      fetch = {
        prune = "true";
        pruneTags = "true";
      };
      init = {
        defaultBranch = "main";
      };
      merge = {
        conflictstyle = "zdiff3";
      };
      pull = {
        ff = "only";
        prune = "true";
      };
      push = {
        autoSetupRemote = true;
      };
      rebase = {
        autoStash = "true";
      };

      rerere.enable = true;
    };

    lfs.enable = true;
  };
}
