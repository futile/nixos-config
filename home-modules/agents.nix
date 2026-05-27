{
  config,
  flake-inputs,
  pkgs,
  thisFlakePath,
  ...
}:
let
  # Caveman is pinned as a non-flake input so updates stay reviewable in
  # flake.lock. Apply a tiny local patch to its upstream caveman-compress skill
  # so Codex can use the running agent for compression when the upstream
  # `claude`-based CLI path is unavailable.
  #
  # To update: run `nix flake update caveman`, rebuild this derivation, and if
  # the patch no longer applies, refresh
  # dotfiles/agents/patches/caveman-compress-current-agent.patch against
  # `${flake-inputs.caveman}/skills/caveman-compress/SKILL.md`.
  cavemanCompressSkill = pkgs.applyPatches {
    name = "caveman-compress-skill";
    src = "${flake-inputs.caveman}/skills/caveman-compress";
    patches = [ ../dotfiles/agents/patches/caveman-compress-current-agent.patch ];
  };
in
{
  home.file.".agents/skills/avoiding-duplicate-builds-in-worktrees".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/agents/skills/avoiding-duplicate-builds-in-worktrees";

  home.file.".agents/skills/find-skills".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/agents/skills/find-skills";

  home.file.".agents/skills/caveman-compress".source = cavemanCompressSkill;
}
