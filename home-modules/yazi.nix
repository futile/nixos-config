{ ... }:
{
  programs.yazi = {
    enable = true;

    enableBashIntegration = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;

    # 2026-03-08 modern version is "y", but I don't use this a lot anyway,
    # so keep the old behavior to silence the warning.
    shellWrapperName = "yy";
  };
}
