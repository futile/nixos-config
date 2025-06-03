{ config, thisFlakePath, ... }:
{
  home.file."Library/KeyBindings/DefaultKeyBinding.dict".source =
    config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/macos/DefaultKeyBinding.dict";
}
