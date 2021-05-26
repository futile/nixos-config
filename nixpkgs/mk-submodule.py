#!/usr/bin/env python3

import argparse
import os
import subprocess
from pathlib import Path


def run_command(*args, **kwargs):
    kwargs.setdefault("check", True)
    return subprocess.run(*args, **kwargs)


def main():
    parser = argparse.ArgumentParser(
        description="Create a nixpkgs-submodule for use in the configuration."
    )
    parser.add_argument(
        "--target-dir",
        type=Path,
        default=Path(__file__).resolve().parent,
        help="directory to create the submodule in (default: directory of this file)",
    )
    parser.add_argument("name", type=str, help="name of the new submodule")
    parser.add_argument(
        "upstream_branch",
        type=str,
        default="master",
        help="name of the upstream branch to base on (default: master)",
    )
    args = parser.parse_args()

    os.chdir(args.target_dir)

    submodule_path = Path(args.name)

    if submodule_path.exists():
        raise ValueError(f"Path '{args.name}' already exist, can't create submodule")

    run_command(
        [
            "git",
            "submodule",
            "add",
            "--depth",
            "1",
            "--name",
            args.name,
            "--",
            "git@github.com:futile/nixpkgs.git",
            str(submodule_path)
        ]
    )

    if not submodule_path.exists():
        raise RuntimeError("submodule path doesn't exist after 'git submodule add'")

    os.chdir(submodule_path)

    run_command(["git", "remote", "add", "upstream", "git@github.com:NixOS/nixpkgs.git"])
    run_command(["git", "fetch", "--depth", "1", "upstream", args.upstream_branch])
    run_command(["git", "checkout", "-b", args.name, f"upstream/{args.upstream_branch}"])


if __name__ == "__main__":
    main()
