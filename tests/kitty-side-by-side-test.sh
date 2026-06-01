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

require_active_regex() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if ! awk -v pattern="${pattern}" '
    /^[[:space:]]*\/\// { next }
    $0 ~ pattern { found = 1 }
    END { exit found ? 0 : 1 }
  ' "${path}"; then
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

require_no_active_regex() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if awk -v pattern="${pattern}" '
    /^[[:space:]]*\/\// { next }
    $0 ~ pattern { found = 1; exit }
    END { exit found ? 0 : 1 }
  ' "${path}"; then
    fail "${message}"
  fi
}

require_linux_block_contains() {
  local path="$1"
  local needle="$2"
  local message="$3"

  if ! awk -v needle="${needle}" '
    function brace_delta(line, tmp, opens, closes) {
      tmp = line
      opens = gsub(/\{/, "{", tmp)
      tmp = line
      closes = gsub(/\}/, "}", tmp)
      return opens - closes
    }

    !in_block && $0 ~ /(lib|pkgs\.lib)\.mkIf pkgs\.stdenv\.isLinux[[:space:]]*\{/ {
      in_block = 1
      depth = brace_delta($0)
    }

    in_block {
      if (index($0, needle)) {
        found = 1
      }

      if (!($0 ~ /(lib|pkgs\.lib)\.mkIf pkgs\.stdenv\.isLinux[[:space:]]*\{/)) {
        depth += brace_delta($0)
      }

      if (depth <= 0) {
        exit found ? 0 : 1
      }
    }

    END {
      if (!in_block || !found) {
        exit 1
      }
    }
  ' "${path}"; then
    fail "${message}"
  fi
}

require_text_block_contains() {
  local path="$1"
  local attr="$2"
  local needle="$3"
  local message="$4"

  if ! awk -v attr="${attr}" -v needle="${needle}" '
    !in_block && index($0, attr) {
      in_block = 1
    }

    in_block && index($0, needle) {
      found = 1
    }

    in_block && /^[[:space:]]*'\'''\'';[[:space:]]*$/ {
      exit found ? 0 : 1
    }

    END {
      if (!in_block || !found) {
        exit 1
      }
    }
  ' "${path}"; then
    fail "${message}"
  fi
}

kitty_module="home-modules/kitty.nix"
kitty_conf="dotfiles/kitty/kitty.conf"
kitty_template="dotfiles/kitty/noctalia.conf.template"
home_host="hosts/nixos-home/home.nix"
work_host="hosts/nixos-work/home.nix"
noctalia_templates="dotfiles/noctalia/nixos-work/user-templates.toml"
niri_config="dotfiles/niri/config.kdl"

kitty_module_exists=0
kitty_conf_exists=0
kitty_template_exists=0

if require_file "${kitty_module}"; then
  kitty_module_exists=1
fi

if require_file "${kitty_conf}"; then
  kitty_conf_exists=1
fi

if require_file "${kitty_template}"; then
  kitty_template_exists=1
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
  require_regex "${kitty_module}" 'home\.packages = pkgs\.lib\.optionals pkgs\.stdenv\.isLinux \[ pkgs\.kitty \];' \
    "${kitty_module} must install pkgs.kitty only on Linux"
  require_linux_block_contains "${kitty_module}" 'kitty/kitty.conf".source' \
    "${kitty_module} must symlink kitty/kitty.conf inside the Linux-only Kitty setup"
  require_linux_block_contains "${kitty_module}" 'kitty/noctalia.conf.template".source' \
    "${kitty_module} must symlink kitty/noctalia.conf.template inside the Linux-only Kitty setup"
  require_linux_block_contains "${kitty_module}" 'mkOutOfStoreSymlink' \
    "${kitty_module} must symlink Kitty config from the repo inside the Linux-only Kitty setup"
  require_linux_block_contains "${kitty_module}" 'dotfiles/kitty/kitty.conf' \
    "${kitty_module} must reference dotfiles/kitty/kitty.conf inside the Linux-only Kitty setup"
  require_linux_block_contains "${kitty_module}" 'dotfiles/kitty/noctalia.conf.template' \
    "${kitty_module} must reference dotfiles/kitty/noctalia.conf.template inside the Linux-only Kitty setup"
  require_linux_block_contains "${kitty_module}" 'kitty/themes/lume.conf".source' \
    "${kitty_module} must provide Lume as a normal Kitty theme"
  require_text_block_contains "${kitty_module}" '"kitty/theme.conf".text' 'include themes/lume.conf' \
    "${kitty_module} must define the default kitty/theme.conf include with themes/lume.conf"
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

require_fixed "${work_host}" 'kitty/theme.conf' \
  "${work_host} must override kitty/theme.conf"
require_text_block_contains "${work_host}" '"kitty/theme.conf".text' 'include themes/lume.conf' \
  "${work_host} Kitty theme override must include themes/lume.conf in xdg.configFile.\"kitty/theme.conf\""
  require_text_block_contains "${work_host}" '"kitty/theme.conf".text' 'globinclude themes/noctalia.conf' \
    "${work_host} Kitty theme override must globinclude themes/noctalia.conf in xdg.configFile.\"kitty/theme.conf\""

if require_file "${noctalia_templates}"; then
  require_no_regex "${noctalia_templates}" '^\[templates\.kitty\]' \
    "${noctalia_templates} must use Noctalia's built-in Kitty template instead of a custom one"
fi

if require_file "${niri_config}"; then
  require_active_regex "${niri_config}" 'Mod[+]T.*spawn[[:space:]]+"wezterm"' \
    "${niri_config} must keep the existing WezTerm launcher on Mod+T"
  require_no_active_regex "${niri_config}" 'spawn[[:space:]]+"kitty"' \
    "${niri_config} must not add an active Kitty spawn binding"
  require_no_active_regex "${niri_config}" 'hotkey-overlay-title="[^"]*[Kk]itty' \
    "${niri_config} must not add an active Kitty hotkey title"
fi

if (( failures )); then
  exit 1
fi

printf 'kitty side-by-side checks passed\n'
