{
  pkgs,
  ...
}:
{
  programs.firefox = {
    enable = true;
    package = pkgs.nixpkgs-unstable.firefox;
  };
}
