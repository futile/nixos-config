# rustup with a `cargo` that runs in background-build.slice (low CPU weight), so builds
# yield to the desktop. Programs started by `cargo run` go back to app.slice.
# Opt out per command with CARGO_NO_BUILD_SLICE=1.
{
  lib,
  rustup,
  stdenv,
  symlinkJoin,
  systemd,
  writeShellScript,
  writeShellScriptBin,
}:
let
  # Explicit unit names: the default run-p<PID>-i<inode> name collides when a scope's
  # process execs into another systemd-run --scope.
  systemdRun = "${systemd}/bin/systemd-run";
  triple = stdenv.hostPlatform.rust.rustcTarget;
  runnerVar = "CARGO_TARGET_${lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] triple)}_RUNNER";

  runInAppSlice = writeShellScript "cargo-run-in-app-slice" ''
    exec ${systemdRun} --user --scope --quiet --collect --slice=app.slice --unit="cargo-run-$$-$SRANDOM" -- "$@"
  '';

  cargo = writeShellScriptBin "cargo" ''
    real=${rustup}/bin/cargo

    # No user manager (ssh, early boot, containers) or already inside a build scope.
    if [[ -n ''${CARGO_NO_BUILD_SLICE:-} || ! -S ''${XDG_RUNTIME_DIR:-/nonexistent}/bus \
          || $(</proc/self/cgroup) == */background-build.slice/* ]]; then
      exec "$real" "$@"
    fi

    # shortcut: only checks cwd ancestors and CARGO_HOME, ignores -C/--config; extend if a
    # project's own runner gets overridden.
    has_config_runner() {
      local d=$PWD f
      while :; do
        for f in "$d/.cargo/config.toml" "$d/.cargo/config"; do
          [[ -f $f && $(<"$f") == *runner* ]] && return 0
        done
        [[ -z $d || $d == / ]] && break
        d=''${d%/*}
      done
      for f in "''${CARGO_HOME:-$HOME/.cargo}"/config{.toml,}; do
        [[ -f $f && $(<"$f") == *runner* ]] && return 0
      done
      return 1
    }

    # First non-option argument is the subcommand.
    sub=
    args=("$@")
    for ((i = 0; i < ''${#args[@]}; i++)); do
      case ''${args[i]} in
        -Z | -C | --config | --color) i=$((i + 1)) ;;
        +* | -*) ;;
        *) sub=''${args[i]}; break ;;
      esac
    done

    # An env runner, unlike a ~/.cargo/config one, does not affect `cargo test`/nextest.
    if [[ ($sub == run || $sub == r) && -z ''${${runnerVar}:-} ]] && ! has_config_runner; then
      export ${runnerVar}=${runInAppSlice}
    fi

    exec ${systemdRun} --user --scope --quiet --collect --slice=background-build.slice \
      --unit="cargo-$$-$SRANDOM" -- "$real" "$@"
  '';
in
symlinkJoin {
  name = "rustup-build-slice";
  paths = [ rustup ];
  postBuild = ''
    rm $out/bin/cargo
    ln -s ${cargo}/bin/cargo $out/bin/cargo
  '';
}
