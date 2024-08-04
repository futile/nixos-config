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

      rerere.enabled = true;
    };

    delta = {
      enable = false;
      # options = {
      #   syntax-theme = "GitHub";
      # };
    };

    difftastic = {
      enable = true;
      # display = "inline"; # default is better imo, I think
    };

    lfs.enable = true;
  };

  programs.gh = {
    enable = true;

    settings = {
      git_protocol = "ssh";
    };
  };

  home.packages = [
    pkgs.git-absorb # nifty git tool that automatically folds staged changes into their corresponding commits: https://github.com/tummychow/git-absorb
    pkgs.git-town # git-town, see https://www.git-town.com/introduction
  ];
}
