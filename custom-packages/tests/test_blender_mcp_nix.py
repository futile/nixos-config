"""Run with the packaged upstream suite via nix build .#mcp-for-blender."""

import asyncio
import json
import types

import pytest

from conftest import ROOT_ADDON
from test_polypizza import _load_addon, _scene


def test_nix_owns_addon_updates(monkeypatch, tmp_path):
    addon = _load_addon(monkeypatch, _scene())
    monkeypatch.delenv("BLENDERMCP_NO_UPDATE_CHECK", raising=False)

    def unexpected_thread(*args, **kwargs):
        pytest.fail("The Nix add-on must not start an update check")

    monkeypatch.setattr(addon.threading, "Thread", unexpected_thread)
    addon._addon_update_check_on_startup()
    assert addon.BLENDERMCP_OT_CheckAddonUpdate().execute(None) == {"FINISHED"}

    labels = []
    addon.draw_addon_update(types.SimpleNamespace(label=lambda **kw: labels.append(kw["text"])))
    assert labels == ["Add-on updates are managed by Nix"]

    target = tmp_path / "blender_mcp.py"
    source = ROOT_ADDON.read_text(encoding="utf-8")
    target.write_text(source, encoding="utf-8")
    with pytest.raises(RuntimeError, match="managed by Nix"):
        addon.install_addon_update(str(target), source)
    assert target.read_text(encoding="utf-8") == source
    assert list(tmp_path.iterdir()) == [target]


def test_mcp_update_guidance_uses_nix(monkeypatch):
    from blender_mcp import addon_manager, server

    monkeypatch.setattr(server, "get_blender_connection", lambda: object())
    monkeypatch.setattr(server, "_maybe_handshake_addon", lambda _: None)
    monkeypatch.setattr(server, "_addon_handshake", addon_manager.AddonHandshake(
        up_to_date=False, protocol_version=1, addon_version=[1, 0, 0],
        capabilities=[], blender_version="5.2.2", source="native",
    ))
    payload = json.loads(asyncio.run(server.get_addon_status(None)))
    assert payload["update_command"] is None
    assert "Nix/Home Manager" in payload["update_instructions"]
    assert "uvx" not in payload["update_instructions"]
    assert "Nix/Home Manager" in server.get_addon_status.__doc__
    assert "Nix/Home Manager" in server.TRIPO_UNAVAILABLE
