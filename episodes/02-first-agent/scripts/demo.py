"""Verify, review, check, and reset the Episode 2 demo."""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import shutil
import subprocess
import sys
from datetime import UTC, datetime
from importlib.metadata import version
from pathlib import Path


EPISODE_DIR = Path(__file__).resolve().parents[1]
ANALYTICS_DIR = EPISODE_DIR / "analytics"
STATE_FILE = EPISODE_DIR / ".demo-state.json"
BASELINE_DIR = EPISODE_DIR / ".demo-baseline"
TARGET_RELATIVE = Path("analytics/models/staging/_staging.yml")
IGNORED_PARTS = {
    ".demo-baseline",
    ".venv",
    "__pycache__",
    "dbt_packages",
    "experiments",
    "logs",
    "target",
}
IGNORED_NAMES = {".demo-state.json", ".user.yml", "analytics.duckdb", "analytics.duckdb.wal"}


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def project_files() -> dict[str, str]:
    files: dict[str, str] = {}
    for path in sorted(EPISODE_DIR.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(EPISODE_DIR)
        if any(part in IGNORED_PARTS for part in relative.parts):
            continue
        if path.name in IGNORED_NAMES:
            continue
        files[relative.as_posix()] = file_hash(path)
    return files


def dbt_command() -> Path:
    candidates = [
        EPISODE_DIR / ".venv" / "bin" / "dbt",
        EPISODE_DIR / ".venv" / "Scripts" / "dbt.exe",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    found = shutil.which("dbt")
    if found:
        return Path(found)
    raise RuntimeError("dbt was not found. Run scripts/setup_demo.py first.")


def run_dbt(*arguments: str) -> None:
    subprocess.run([str(dbt_command()), *arguments], cwd=ANALYTICS_DIR, check=True)


def verify() -> int:
    if sys.version_info[:2] != (3, 12):
        print("The demo must run with Python 3.12.")
        return 1

    print(f"dbt-core {version('dbt-core')}, dbt-duckdb {version('dbt-duckdb')}, DuckDB {version('duckdb')}", flush=True)
    print("Running the known passing build against the local DuckDB project...", flush=True)
    run_dbt("build", "--select", "stg_pos__transactions")

    BASELINE_DIR.mkdir(exist_ok=True)
    target = EPISODE_DIR / TARGET_RELATIVE
    shutil.copy2(target, BASELINE_DIR / "_staging.yml")
    state = {
        "created_at": datetime.now(UTC).isoformat(),
        "files": project_files(),
        "target": TARGET_RELATIVE.as_posix(),
    }
    STATE_FILE.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print()
    print("Baseline ready.")
    print(f"Recorded {len(state['files'])} project files for later review.")
    return 0


def load_state() -> dict[str, object]:
    if not STATE_FILE.exists() or not (BASELINE_DIR / "_staging.yml").exists():
        raise RuntimeError("No baseline snapshot exists. Run the verify command first.")
    return json.loads(STATE_FILE.read_text(encoding="utf-8"))


def differences() -> tuple[list[str], list[str], list[str]]:
    state = load_state()
    before = state["files"]
    if not isinstance(before, dict):
        raise RuntimeError("The baseline snapshot is invalid.")
    after = project_files()
    before_names = set(before)
    after_names = set(after)
    modified = sorted(name for name in before_names & after_names if before[name] != after[name])
    added = sorted(after_names - before_names)
    deleted = sorted(before_names - after_names)
    return modified, added, deleted


def review() -> int:
    modified, added, deleted = differences()
    print("Files changed since setup:")
    if not modified and not added and not deleted:
        print("  none")
        return 1
    for name in modified:
        print(f"  modified  {name}")
    for name in added:
        print(f"  added     {name}")
    for name in deleted:
        print(f"  deleted   {name}")

    baseline_lines = (BASELINE_DIR / "_staging.yml").read_text(encoding="utf-8").splitlines(keepends=True)
    current_target = EPISODE_DIR / TARGET_RELATIVE
    if current_target.exists() and TARGET_RELATIVE.as_posix() in modified:
        current_lines = current_target.read_text(encoding="utf-8").splitlines(keepends=True)
        print()
        print("Exact change in _staging.yml:")
        print(
            "".join(
                difflib.unified_diff(
                    baseline_lines,
                    current_lines,
                    fromfile="before/_staging.yml",
                    tofile="after/_staging.yml",
                )
            ),
            end="",
        )

    expected = {TARGET_RELATIVE.as_posix()}
    unexpected = (set(modified) | set(added) | set(deleted)) - expected
    print()
    if unexpected:
        print("STOP: the agent changed something outside the allowed file.")
        return 2
    print("Scope check passed: exactly one allowed file changed.")
    return 0


def check() -> int:
    print("Running the selected dbt build independently...", flush=True)
    run_dbt("build", "--select", "stg_pos__transactions")
    print("Independent check passed.")
    return 0


def reset() -> int:
    load_state()
    target = EPISODE_DIR / TARGET_RELATIVE
    shutil.copy2(BASELINE_DIR / "_staging.yml", target)
    database = ANALYTICS_DIR / "analytics.duckdb"
    if database.exists():
        database.unlink()
    for name in ("target", "logs"):
        generated = ANALYTICS_DIR / name
        if generated.exists():
            shutil.rmtree(generated)

    modified, added, deleted = differences()
    if modified or added or deleted:
        print("The allowed file was restored, but other project changes remain:")
        for name in [*modified, *added, *deleted]:
            print(f"  {name}")
        print("Inspect those files or start from a fresh copy.")
        return 2
    print("Demo reset complete. The recorded project files match the baseline.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("verify", "review", "check", "reset"))
    command = parser.parse_args().command
    try:
        return {"verify": verify, "review": review, "check": check, "reset": reset}[command]()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"ERROR: {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
