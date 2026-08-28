"""Create the pinned environment and verify the Episode 2 baseline."""

from __future__ import annotations

import subprocess
import sys
import venv
from pathlib import Path


EPISODE_DIR = Path(__file__).resolve().parents[1]
VENV_DIR = EPISODE_DIR / ".venv"


def venv_python() -> Path:
    if sys.platform == "win32":
        return VENV_DIR / "Scripts" / "python.exe"
    return VENV_DIR / "bin" / "python"


def main() -> int:
    if sys.version_info[:2] != (3, 12):
        print("Python 3.12 is required.")
        print(f"This command is using Python {sys.version_info.major}.{sys.version_info.minor}.")
        return 1

    if not VENV_DIR.exists():
        print("Creating .venv with Python 3.12...", flush=True)
        venv.EnvBuilder(with_pip=True).create(VENV_DIR)
    else:
        print("Using the existing .venv.", flush=True)

    python = venv_python()
    try:
        subprocess.run(
            [
                str(python),
                "-m",
                "pip",
                "install",
                "--quiet",
                "--disable-pip-version-check",
                "-r",
                str(EPISODE_DIR / "requirements.txt"),
            ],
            check=True,
            cwd=EPISODE_DIR,
        )
        subprocess.run(
            [str(python), str(EPISODE_DIR / "scripts" / "demo.py"), "verify"],
            check=True,
            cwd=EPISODE_DIR,
        )
    except subprocess.CalledProcessError:
        print()
        print("Setup failed. Read the command output above, fix the reported problem, and run this setup command again.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
