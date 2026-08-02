#!/usr/bin/env bash
#
# Put episode 1 back to ground zero and reload the seed data.
#
#   ./reset.sh
#
# Ground zero is the `ep01-baseline` tag: a dbt project, a profile, one seed
# file, this script, and the experiments folder. No models, no tests. That is
# the state Claude gets handed when a segment is rebuilt on camera.
#
# This is a production tool, not part of the dbt project, which is why it lives
# here and not inside analytics/.
#
# NOTE: this script is itself restored from the baseline tag, so if you move or
# edit it, commit and re-tag before running it again. Otherwise the reset puts
# the old copy back and deletes the new one.
#
# Ignored files are left alone, so the virtual environment and experiment
# output survive.
#
set -euo pipefail

BASELINE="ep01-baseline"
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
PROJECT="$HERE/analytics"

# Use the venv's dbt directly so this works without activating anything first.
DBT="$HERE/.venv/bin/dbt"
if [[ ! -x "$DBT" ]]; then
    DBT="$(command -v dbt || true)"
    [[ -n "$DBT" ]] || { echo "dbt not found. Is .venv missing?"; exit 1; }
fi

echo
echo "Resetting to tag: $BASELINE"
echo

if ! git -C "$REPO" rev-parse -q --verify "refs/tags/$BASELINE" >/dev/null; then
    echo "Tag '$BASELINE' does not exist. Nothing done."
    exit 1
fi

AHEAD="$(git -C "$REPO" rev-list --count "$BASELINE"..HEAD)"
if [[ "$AHEAD" -gt 0 ]]; then
    echo "WARNING: $AHEAD commit(s) since the baseline will be discarded:"
    echo
    git -C "$REPO" log --oneline "$BASELINE"..HEAD
    echo
    echo "To keep any of that, quit now and run:  git tag keep-<name>"
    echo
fi

echo "Uncommitted changes that will also go:"
git -C "$REPO" status --short
echo

read -r -p "Reset to $BASELINE? [y/N] " reply
if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Nothing changed."
    exit 0
fi

git -C "$REPO" reset --hard "$BASELINE"
git -C "$REPO" clean -fd          # -fd only, never -fdx, which would delete .venv

cd "$PROJECT"
rm -f analytics.duckdb

echo
echo "Ground zero. Landing zone as delivered, no models, no database."
echo "Anything copied from incoming/ into landing/ has been removed."
