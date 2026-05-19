# Safehouse and OpenCode on hm-cf

This documents the `hosts/hm-cf/` Safehouse/OpenCode setup. It is macOS-specific
because Safehouse wraps `sandbox-exec`, and the functions live in the standalone
Home Manager config for the Cloudflare Mac host.

## Fish Functions

The functions are defined in `hosts/hm-cf/home.nix` under
`programs.fish.functions`.

`safe` is the generic Safehouse wrapper:

```fish
safehouse \
  --env \
  --enable=wide-read,ssh,shell-init \
  $argv
```

It inherits the full environment, allows broad read-only visibility, enables SSH
access, and permits shell startup file reads. It should stay generic so other
commands can use the same baseline sandbox without OpenCode-specific writable
paths.

`safe-opencode` is the OpenCode-specific wrapper. It sets OpenCode's internal
permission mode, enables clipboard access, and grants write access to only
OpenCode's runtime directories:

```fish
set -lx OPENCODE_PERMISSION '{"*":"allow"}'

if test -x "$HOME/.git-ai/bin/git-ai"; \
    and not "$HOME/.git-ai/bin/git-ai" bg status >/dev/null 2>&1; \
    and test -e "$HOME/.git-ai/internal/daemon/daemon.lock"; \
    and not test -S "$HOME/.git-ai/internal/daemon/control.sock"
  rm "$HOME/.git-ai/internal/daemon/daemon.lock"
end

safehouse \
  --env \
  --enable=wide-read,ssh,shell-init,clipboard \
  --add-dirs=(string join : \
    "$HOME/.local" \
    "$HOME/.cache" \
    "$HOME/.config/opencode" \
    "$HOME/.git-ai/internal" \
    "$HOME/repos" \
    "$HOME/nixos" \
    "$TMPDIR/opencode") \
  opencode \
  $argv
```

`os` is the Cloudflare OpenCode entrypoint. It checks whether the `cf-portal` MCP
server is authenticated, runs `opencode mcp auth cf-portal` only when needed,
logs in to `https://opencode.cloudflare.dev`, and then delegates the session to
`safe-opencode`.

`safe-opencode` calls `safehouse` directly instead of delegating to `safe`
because Safehouse `--enable` flags are not cumulative when repeated. The generic
`safe` wrapper intentionally does not include `clipboard`; clipboard access is
only granted to OpenCode sessions.

## Writable Paths

The current OpenCode paths from `opencode debug paths` are:

```text
home       /Users/frath
data       /Users/frath/.local/share/opencode
bin        /Users/frath/.cache/opencode/bin
log        /Users/frath/.local/share/opencode/log
repos      /Users/frath/.local/share/opencode/repos
cache      /Users/frath/.cache/opencode
config     /Users/frath/.config/opencode
state      /Users/frath/.local/state/opencode
tmp        /var/folders/lk/jfwvhk7n17bcr90fg2ln4p680000gn/T/opencode
```

Safehouse uses `--add-dirs` for read/write grants. Prefer the spelling
"writable" in docs and variable names; "writeable" is accepted English, but is
less common in technical usage.

The wrapper grants these parent directories instead of every child path:

```text
/Users/frath/.local
/Users/frath/.cache
/Users/frath/.config/opencode
/Users/frath/.git-ai/internal
/Users/frath/repos
/Users/frath/nixos
$TMPDIR/opencode
```

Those parent grants cover the child paths OpenCode reports:

| OpenCode path | Covered by |
|---|---|
| `data` | `~/.local` |
| `log` | `~/.local` |
| `repos` | `~/.local` |
| `cache` | `~/.cache` |
| `bin` | `~/.cache` |
| `config` | `~/.config/opencode` |
| `state` | `~/.local` |
| `tmp` | `$TMPDIR/opencode` |

The `~/.git-ai/internal` grant is for OpenCode's `git-ai` plugin. The plugin
runs `/Users/frath/.git-ai/bin/git-ai checkpoint opencode --hook-input stdin`
around editing tools, and `git-ai` writes daemon locks, sockets, logs, and
SQLite state under `~/.git-ai/internal`. The rest of `~/.git-ai` stays read-only:
OpenCode only needs to execute the installed binary and mutate runtime state.

The `~/repos` and `~/nixos` grants intentionally allow OpenCode to edit source
trees outside the current working directory while keeping the rest of `$HOME`
read-only unless another grant permits it.

Before entering Safehouse, `safe-opencode` also removes a stale
`~/.git-ai/internal/daemon/daemon.lock` only when `git-ai bg status` fails and no
daemon control socket exists. This handles interrupted sessions that leave a lock
behind and would otherwise make every later checkpoint fail with
`daemon startup blocked: lock held`.

Do not add `/Users/frath` as a writable root. That would make most of the home
directory writable and remove much of the value of running OpenCode through
Safehouse.

## Updating the Paths

If OpenCode changes its runtime layout, run:

```sh
opencode debug paths
```

Then update only `safe-opencode` unless a new path is useful for non-OpenCode
commands too. Prefer granting the narrowest stable parent directory that covers
the required OpenCode children.

## Validation

After changing this setup, run:

```sh
just format-check
just hm-build
```

Use `just hm-switch` only when ready to apply the Home Manager changes on the
macOS host.
