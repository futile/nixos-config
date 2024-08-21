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

      git-town = {
        ship-delete-tracking-branch = "false";
        sync-feature-strategy = "rebase";
        sync-perennial-strategy = "rebase";
        sync-upstream = "true";
      };
    };

    aliases = {
      # aliases created by/for `git-town`
      append = "town append";
      compress = "town compress";
      contribute = "town contribute";
      diff-parent = "town diff-parent";
      hack = "town hack";
      kill = "town kill";
      observe = "town observe";
      park = "town park";
      prepend = "town prepend";
      propose = "town propose";
      rename-branch = "town rename-branch";
      repo = "town repo";
      set-parent = "town set-parent";
      sync = "town sync";
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
    pkgs.git-filter-repo # powerful history re-writing tool, use with care! https://github.com/newren/git-filter-repo
    pkgs.git-town # git-town, see https://www.git-town.com/introduction
  ];
}
