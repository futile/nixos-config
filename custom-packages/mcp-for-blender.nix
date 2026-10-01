{
  lib,
  python3,
  fetchPypi,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "mcp-for-blender";
  version = "2.1.3";
  pyproject = true;

  # The GitHub tree omits config.py; the published source distribution includes it.
  src = fetchPypi {
    inherit version;
    pname = "mcp_for_blender";
    hash = "sha256-cYAtcYnMF5dRqzXRPfJPd3b77pXG21rFjaHyFNvwxjI=";
  };

  patches = [
    ./patches/mcp-for-blender-nix-updates.patch
    ./patches/mcp-for-blender-nix-guidance.patch
  ];

  build-system = with python3.pkgs; [
    setuptools
    wheel
  ];

  dependencies = with python3.pkgs; [
    mcp
    httpx
  ];

  makeWrapperArgs = [ "--set DISABLE_TELEMETRY true" ];

  postInstall = ''
    install -Dm644 src/blender_mcp/bundled/addon.py \
      "$out/share/blender/addons/blender_mcp.py"
  '';

  nativeCheckInputs = [ python3.pkgs.pytestCheckHook ];

  preCheck = ''
    export HOME=$(mktemp -d)
    export DISABLE_TELEMETRY=true
    # PyPI includes the tests but omits their root add-on and conftest.py.
    cp src/blender_mcp/bundled/addon.py addon.py
    cat > tests/conftest.py <<'PY'
    from pathlib import Path
    ROOT_ADDON = Path(__file__).resolve().parent.parent / "addon.py"
    PY
    cp ${./tests/test_blender_mcp_nix.py} tests/test_blender_mcp_nix.py
  '';

  disabledTests = [
    # Nix owns updates; the replacement regression checks that writes are blocked.
    "test_install_replaces_the_file_and_keeps_a_backup"
  ];

  pythonImportsCheck = [ "blender_mcp.server" ];

  meta = {
    description = "Control Blender through the Model Context Protocol";
    homepage = "https://github.com/ahujasid/mcp-for-blender";
    license = lib.licenses.mit;
    mainProgram = "mcp-for-blender";
  };
}
