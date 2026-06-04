#!/usr/bin/env python3
# Tag kitty notifications so Noctalia history can be cleared per source tab.
# See docs/superpowers/plans/2026-06-04-kitty-noctalia-notification-footers.md.
import hashlib
import os


def _instance_key() -> str:
    listen_on = os.environ.get("KITTY_LISTEN_ON", "")
    if listen_on:
        return hashlib.sha256(listen_on.encode("utf-8")).hexdigest()[:12]
    return hashlib.sha256(str(os.getpid()).encode("ascii")).hexdigest()[:12]


def _source_footer(channel_id: int) -> str:
    return f"Kitty-Source: kitty:{_instance_key()}:{channel_id}"


def main(cmd) -> bool:
    channel_id = getattr(cmd, "channel_id", 0)
    if not channel_id:
        return False

    footer = _source_footer(channel_id)
    body = getattr(cmd, "body", "") or ""
    if footer not in body:
        cmd.body = body.rstrip() + "\n\n" + footer if body else footer

    return False
