{ config, pkgs, ... }: {
  programs.git = {
    enable = true;
    package = pkgs.gitAndTools.gitFull;
    userName = "Felix Rath";

    extraConfig = {
      init = { defaultBranch = "main"; };
      core = { editor = "nvim"; };
      fetch = { prune = "true"; pruneTags = "true"; };
      pull = { ff = "only"; prune = "true"; };
      rebase = { autoStash = "true"; };
      merge = { conflictstyle = "diff3"; };
    };

    lfs.enable = true;
  };
}
