#!/usr/bin/env python3
# Clear tagged Noctalia notification history when the source kitty tab is focused.
# See docs/superpowers/plans/2026-06-04-kitty-noctalia-notification-footers.md.
import hashlib
import os
import subprocess
import time


CLEAR_SCRIPT = "/home/felix/nixos/bin/kitty-clear-noctalia-for-source"
_last_clear_by_source = {}
_last_active_by_os_window = {}


def _instance_key() -> str:
    listen_on = os.environ.get("KITTY_LISTEN_ON", "")
    if listen_on:
        return hashlib.sha256(listen_on.encode("utf-8")).hexdigest()[:12]
    return hashlib.sha256(str(os.getpid()).encode("ascii")).hexdigest()[:12]


def _source_key(window) -> str:
    return f"kitty:{_instance_key()}:{window.id}"


def _clear_for_window(window) -> None:
    source_key = _source_key(window)
    now = time.monotonic()
    if now - _last_clear_by_source.get(source_key, 0.0) < 0.5:
        return
    _last_clear_by_source[source_key] = now
    subprocess.Popen([CLEAR_SCRIPT, source_key])


def on_focus_change(boss, window, data) -> None:
    if data.get("focused"):
        _clear_for_window(window)


def on_tab_bar_dirty(boss, window, data) -> None:
    active = getattr(boss, "active_window", None)
    if active is None:
        return
    os_window_id = getattr(active, "os_window_id", None)
    previous = _last_active_by_os_window.get(os_window_id)
    if previous == active.id:
        return
    _last_active_by_os_window[os_window_id] = active.id
    _clear_for_window(active)
