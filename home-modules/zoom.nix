{ pkgs, ... }:

{
  home.packages = [ pkgs.unstable.zoom-us ];

  # xdg = {
  # enable = true;
  # from https://github.com/NixOS/nixpkgs/issues/107233#issuecomment-757424877
  # -> do this by hand instead, as the file contains a lot of entries by default. (19.4.21)
  # ".config/zoomus.conf".text = ''
  #   enableWaylandShare=true
  # '';
  # };
}
