# tools

The scripts that produced the landing data. They exist so the committed CSV files can be
reproduced from source. Nobody needs them to follow an episode.

`git sparse-checkout` does not write this folder into an episode clone, so a viewer following a
lesson never has it on disk.

## Requirements

```bash
python3.12 -m venv .venv
.venv/bin/python -m pip install faker
```

`faker` is used by `generate_landing.py` only. It is deliberately not in any episode's
`requirements.txt`, because an episode environment pins what the dbt project needs and nothing
else.

## The scripts, in order

They are ordered. The second reads what the first produced.

### 1. `generate_landing.py`

Writes the first two nights of deliveries from all four source systems into
`episodes/01-still-a-data-engineer/analytics/landing/`, and one held-back file into that
episode's `test-data/`.

**It deletes and rewrites that landing zone.** Run it only to reproduce the committed files.
Check `git status` afterwards. A clean run leaves every file byte-identical to what is committed,
because `SEED` fixes every random choice.

Episodes 2, 3 and 4 each copied that landing zone forward unchanged, so the same 16 files appear
in each episode folder.

### 2. `generate_pos_night3.py`

Writes a third night of point-of-sale deliveries into
`episodes/04-full-build/test-data/pos/`.

It reads the point-of-sale files already in `episodes/04-full-build/analytics/landing/pos/` to
find the highest transaction number in use, so **it cannot run before step 1 has produced those
files**.

The third night exists because Episode 4 needs a delivery that arrives after the first build, and
because the first two nights contain no refund, no void and no repeated transaction id. It is
held back in `test-data/` and copied into the landing zone during the episode.

## Reproducing everything from scratch

```bash
.venv/bin/python tools/generate_landing.py
# copy the episode 1 landing zone forward to each later episode folder
.venv/bin/python tools/generate_pos_night3.py
git status --short        # expect no changes
```
