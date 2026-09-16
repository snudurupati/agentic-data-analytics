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

Only needed if the committed CSV files are lost and Git cannot restore them. If they are merely
deleted from a working tree, `git restore` brings them back and no script is required.

Run these in order, from the repository root.

```bash
python3 -m venv .venv
.venv/bin/python -m pip install faker

# 1. The first two nights, all four source systems. Writes into episode 1
#    and deletes that episode's landing zone first.
.venv/bin/python tools/generate_landing.py

# 2. Copy episode 1's landing zone forward. Every episode uses the same 16 files.
for e in 02-first-agent 03-project-context 04-full-build; do
  cp -R episodes/01-still-a-data-engineer/analytics/landing/. "episodes/$e/analytics/landing/"
done

# 3. Copy episode 1's held-back file forward to episode 2, which also ships one.
cp -R episodes/01-still-a-data-engineer/test-data/. episodes/02-first-agent/test-data/

# 4. The third night of point-of-sale files, for episode 4. Reads the files
#    step 2 placed in episode 4, so it must run after it.
.venv/bin/python tools/generate_pos_night3.py

# 5. Verify. A correct rebuild changes nothing.
git status --short -- '*.csv'
```

Step 5 must print nothing. Step 3 is easy to miss: three episodes carry a `test-data` folder, not
two, so copying only `landing/` leaves the rebuild one file short and everything else looking
correct.

This sequence was verified by deleting all 68 committed CSV files and rebuilding them. Every file
came back byte-identical.
