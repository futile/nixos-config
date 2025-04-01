#!/usr/bin/env bash
set -euo pipefail

# automation for the steps from `mac.md`

cd "/Users/frath/Applications/Home Manager Trampolines/Brave Browser.app/Contents/MacOS"

rm "./applet" || true

# quoted "EOF" prevents argument interpolation
cat <<"EOF" >"./applet"
#!/usr/bin/env bash
exec brave $@
EOF

chmod +x "./applet"
