#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

failures=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=1
}

require_file() {
  local path="$1"

  if [[ ! -f "${path}" ]]; then
    fail "missing ${path}"
    return 1
  fi

  return 0
}

require_fixed() {
  local path="$1"
  local needle="$2"
  local message="$3"

  if ! grep -Fq -- "${needle}" "${path}"; then
    fail "${message}"
  fi
}

require_regex() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if ! grep -Eq -- "${pattern}" "${path}"; then
    fail "${message}"
  fi
}

require_no_regex() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq -- "${pattern}" "${path}"; then
    fail "${message}"
  fi
}

kitty_module="home-modules/kitty.nix"
kitty_conf="dotfiles/kitty/kitty.conf"
kitty_template="dotfiles/kitty/noctalia.conf.template"
kitty_theme="dotfiles/kitty/theme.conf"
home_host="hosts/nixos-home/home.nix"
work_host="hosts/nixos-work/home.nix"
noctalia_templates="dotfiles/noctalia/nixos-work/user-templates.toml"
niri_config="dotfiles/niri/config.kdl"

kitty_module_exists=0
kitty_conf_exists=0
kitty_template_exists=0
kitty_theme_exists=0

if require_file "${kitty_module}"; then
  kitty_module_exists=1
fi

if require_file "${kitty_conf}"; then
  kitty_conf_exists=1
fi

if require_file "${kitty_template}"; then
  kitty_template_exists=1
fi

if require_file "${kitty_theme}"; then
  kitty_theme_exists=1
fi

require_fixed "${home_host}" '"${home-modules}/kitty.nix"' \
  "${home_host} must import home-modules/kitty.nix"
require_fixed "${work_host}" '"${home-modules}/kitty.nix"' \
  "${work_host} must import home-modules/kitty.nix"

require_fixed "${home_host}" '"${home-modules}/wezterm.nix"' \
  "${home_host} must keep importing home-modules/wezterm.nix"
require_fixed "${work_host}" '"${home-modules}/wezterm.nix"' \
  "${work_host} must keep importing home-modules/wezterm.nix"

if (( kitty_module_exists )); then
  require_regex "${kitty_module}" '(lib|pkgs\.lib)\.mkIf pkgs\.stdenv\.isLinux' \
    "${kitty_module} must gate Kitty setup to Linux"
  require_fixed "${kitty_module}" 'pkgs.kitty' \
    "${kitty_module} must install pkgs.kitty"
  require_fixed "${kitty_module}" 'kitty/kitty.conf".source' \
    "${kitty_module} must symlink kitty/kitty.conf"
  require_fixed "${kitty_module}" 'kitty/noctalia.conf.template".source' \
    "${kitty_module} must symlink kitty/noctalia.conf.template"
  require_fixed "${kitty_module}" 'mkOutOfStoreSymlink' \
    "${kitty_module} must symlink Kitty config from the repo"
  require_fixed "${kitty_module}" 'dotfiles/kitty/kitty.conf' \
    "${kitty_module} must reference dotfiles/kitty/kitty.conf"
  require_fixed "${kitty_module}" 'dotfiles/kitty/noctalia.conf.template' \
    "${kitty_module} must reference dotfiles/kitty/noctalia.conf.template"
fi

if (( kitty_conf_exists )); then
  require_fixed "${kitty_conf}" 'term xterm-kitty' \
    "${kitty_conf} must set term xterm-kitty"
  require_fixed "${kitty_conf}" 'terminfo_type path' \
    "${kitty_conf} must set terminfo_type path"
  require_fixed "${kitty_conf}" 'shell_integration enabled' \
    "${kitty_conf} must enable shell integration"
  require_fixed "${kitty_conf}" 'notify_on_cmd_finish unfocused 10.0 notify focus next' \
    "${kitty_conf} must enable unfocused command-finish notifications"
  require_fixed "${kitty_conf}" 'include theme.conf' \
    "${kitty_conf} must include theme.conf"
fi

if (( kitty_theme_exists )); then
  require_fixed "${kitty_theme}" 'include colors/lume.conf' \
    "${kitty_theme} must include colors/lume.conf"
fi

require_fixed "${work_host}" 'kitty/theme.conf' \
  "${work_host} must override kitty/theme.conf"
require_fixed "${work_host}" 'colors/lume.conf' \
  "${work_host} Kitty theme override must include colors/lume.conf"
require_fixed "${work_host}" 'globinclude noctalia.conf' \
  "${work_host} Kitty theme override must globinclude noctalia.conf"

if require_file "${noctalia_templates}"; then
  require_fixed "${noctalia_templates}" '[templates.kitty]' \
    "${noctalia_templates} must define [templates.kitty]"
  require_fixed "${noctalia_templates}" 'input_path = "~/.config/kitty/noctalia.conf.template"' \
    "${noctalia_templates} must read ~/.config/kitty/noctalia.conf.template"
  require_fixed "${noctalia_templates}" 'output_path = "~/.config/kitty/noctalia.conf"' \
    "${noctalia_templates} must write ~/.config/kitty/noctalia.conf"
fi

if require_file "${niri_config}"; then
  require_fixed "${niri_config}" 'Mod+T hotkey-overlay-title="Open a Terminal: wezterm" { spawn "wezterm"; }' \
    "${niri_config} must keep the existing WezTerm launcher"
  require_no_regex "${niri_config}" 'spawn\s+"kitty"' \
    "${niri_config} must not add a Kitty spawn binding"
  require_no_regex "${niri_config}" 'hotkey-overlay-title="[^"]*[Kk]itty' \
    "${niri_config} must not add a Kitty hotkey title"
fi

if (( failures )); then
  exit 1
fi

printf 'kitty side-by-side checks passed\n'
