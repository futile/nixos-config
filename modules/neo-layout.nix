{ ... }: {
  # console keymap
  console.keyMap = "neo";

  # Configure keymap in X11
  services.xserver = {
    layout = "de,de";
    xkbVariant = "neo,basic";
    # xkbOptions = "grp:menu_toggle"; # 'menu_toggle' -> context-menu key
  };
}
