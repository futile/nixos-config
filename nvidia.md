# Nvidia stuff (I guess)

Enable "Force Full Composition Pipeline" under "XServer Display Configuration" -> "Advanced...".
Prevents screen tearing in fullscreen mpv (maybe in other places as well).
From <https://wiki.archlinux.org/title/NVIDIA/Troubleshooting#Avoid_screen_tearing>
I did this in the "Nvidia Settings" GUI application.

-> I now do this using `hardware.nvidia.forceFullCompositionPipeline = true;`
