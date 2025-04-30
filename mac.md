## How to fix the generated trampoline for Brave being unable to open links

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
```

## How to fix Brave permissions issues with screen sharing

1. Remove manually in Settings
2. Start Brave, open a google meet, accept all the prompts and turn on screen sharing for Brave
3. Restart Brave -> screen sharing should work now
