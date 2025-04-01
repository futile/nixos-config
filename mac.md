# How to fix the generated trampoline for Brave being unable to open links

The below steps are now automated in `scripts/fix_brave_applet.sh`.

```console
❯ pwd
/Users/frath/Applications/Home Manager Trampolines/Brave Browser.app/Contents/MacOS

❯ cat applet
───────┬──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
       │ File: applet
───────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1   │ #!/usr/bin/env bash
   2   │ exec brave $@
´´´
