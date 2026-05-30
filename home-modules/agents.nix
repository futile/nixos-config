{
  config,
  flake-inputs,
  pkgs,
  thisFlakePath,
  ...
}:
let
  # Caveman is pinned as a non-flake input so updates stay reviewable in
  # flake.lock. Reuse upstream helper scripts, but replace SKILL.md with our
  # repo-owned instructions because the workflow is adapted for Codex and for
  # explicit source-to-output compression without backup files.
  #
  # To update: run `nix flake update caveman`, rebuild this derivation, and
  # review whether upstream `skills/caveman-compress/scripts/` changed in a way
  # that requires updating dotfiles/agents/skills/caveman-compress/SKILL.md.
  cavemanCompressSkill = pkgs.runCommand "caveman-compress-skill" { } ''
    cp -R ${flake-inputs.caveman}/skills/caveman-compress "$out"
    chmod -R u+w "$out"
    cp ${../dotfiles/agents/skills/caveman-compress/SKILL.md} "$out/SKILL.md"
  '';
in
{
  home.file.".agents/skills/find-skills".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/agents/skills/find-skills";

  home.file.".agents/skills/spark-delegate".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/agents/skills/spark-delegate";

  home.file.".agents/skills/caveman-compress".source = cavemanCompressSkill;
}
