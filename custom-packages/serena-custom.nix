{
  lib,
  python3Packages,
  fetchFromGitHub,
  editorTools ? [ ],
  version ? "1.5.3",
  src ? fetchFromGitHub {
    owner = "oraios";
    repo = "serena";
    tag = "v${version}";
    hash = "sha256-8RHjJG8loqC742LoFK7O3MK7JDEhb1qw8VMBhzj04MM=";
  },
}:

python3Packages.buildPythonApplication rec {
  pname = "serena-custom";
  inherit version src;
  pyproject = true;
  __structuredAttrs = true;

  disabled = python3Packages.pythonOlder "3.11";

  patches = [
    ./patches/serena-rust-analyzer-initialization-options.patch
  ];

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail '"dotenv==0.9.9",' ""
  '';

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    anthropic
    beautifulsoup4
    cryptography
    docstring-parser
    filelock
    flask
    jinja2
    joblib
    lsprotocol
    mcp
    overrides
    pathspec
    psutil
    pydantic
    pygls
    pystray
    python-dotenv
    python-multipart
    pywebview
    pyyaml
    regex
    requests
    ruamel-yaml
    sensai-utils
    starlette
    tiktoken
    tqdm
    types-pyyaml
    urllib3
    werkzeug
  ];

  pythonRelaxDeps = [
    "anthropic"
    "beautifulsoup4"
    "cryptography"
    "docstring-parser"
    "filelock"
    "flask"
    "jinja2"
    "joblib"
    "lsprotocol"
    "mcp"
    "overrides"
    "pathspec"
    "psutil"
    "pydantic"
    "pygls"
    "pystray"
    "python-dotenv"
    "python-multipart"
    "pywebview"
    "pyyaml"
    "regex"
    "requests"
    "ruamel-yaml"
    "sensai-utils"
    "starlette"
    "tiktoken"
    "tqdm"
    "types-pyyaml"
    "urllib3"
    "werkzeug"
  ];

  pythonImportsCheck = [ "serena" ];

  makeWrapperArgs = lib.optionals (editorTools != [ ]) [
    "--suffix"
    "PATH"
    ":"
    (lib.makeBinPath editorTools)
  ];

  meta = {
    description = "Coding agent toolkit providing semantic code operations for LLMs via MCP";
    homepage = "https://github.com/oraios/serena";
    changelog = "https://github.com/oraios/serena/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "serena";
    platforms = lib.platforms.unix;
  };
}
