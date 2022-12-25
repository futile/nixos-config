#!/usr/bin/env bash
set -euo pipefail

nitrogen --restore &
xsettingsd &
xrdb -merge "$HOME/.Xresources"
