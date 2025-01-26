{ ... }: {
  # console keymap
  console.keyMap = "neo";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "de,de";
    variant = "neo,nodeadkeys";
    # xkbOptions = "grp:menu_toggle"; # 'menu_toggle' -> context-menu key
  };
}
