# Episode 1: Am I still a data engineer if Claude does the work?

A dbt project over a landing zone of files from four source systems: a CRM, an ERP, an e-commerce
platform, and point-of-sale terminals in eight branches. Everything runs locally on DuckDB. No
cloud account, no paid tooling, nothing behind a signup wall.

## Setup with an agent

If you use a coding agent, paste this and it will do the rest:

```text
Clone https://github.com/snudurupati/agentic-data-analytics.git into a new
directory called ada.

Then read AGENTS.md at the repository root and
episodes/01-still-a-data-engineer/README.md, and follow them to build the
environment for episode 1.

Build the environment with Python 3.12. If a virtual environment is already
active, deactivate it first, and use an absolute path to the interpreter rather
than whatever python3.12 resolves to on PATH, because an unrelated venv can
shadow it. After creating the venv, confirm with .venv/bin/python --version
that it really is 3.12. Then install exactly the pinned versions in
requirements.txt.

Finally, check out the baseline branch, which is the starting state.

When you are finished, verify by running `dbt debug` from the analytics
directory and show me the output, and tell me which branch I am on.

Set up the environment only. Do not write any models, tests or macros, do not
run reset.sh, and do not modify anything under landing/ or incoming/.
```

The last paragraph matters. Without it an agent will often start building models, because that is
what a dbt project with no models looks like it needs.

## Setup by hand

Python 3.12 is required. dbt and DuckDB are pinned in `requirements.txt` because both change
behaviour between minor versions.

```bash
git clone https://github.com/snudurupati/agentic-data-analytics.git ada
cd ada/episodes/01-still-a-data-engineer
git checkout baseline
```

If you already have a virtual environment active, `deactivate` it first. Another project's
`python3.12` can sit ahead of the real one on your PATH, so use an absolute path:

```bash
/opt/homebrew/bin/python3.12 -m venv .venv     # or `which -a python3.12` to find yours
.venv/bin/python --version                     # must say 3.12.x
source .venv/bin/activate
pip install -r requirements.txt
```

Verify:

```bash
cd analytics
dbt --version
dbt debug
```

`dbt debug` should report a working DuckDB connection and end with "All checks passed!".
`profiles.yml` is committed and uses a relative path, so there is nothing to configure in `~/.dbt`.

`dbt --version` will note that newer dbt and dbt-duckdb releases exist. Leave the pins alone. They
are what the episode was recorded against.

## Starting state

`ep01-baseline` is the state everything begins from: the landing zone, an empty dbt project, and
the team's conventions. No models, no tests, no database.

```bash
git checkout baseline
./reset.sh
```

`reset.sh` discards commits and uncommitted changes, drops the DuckDB file, and removes anything
copied into `landing/`. It asks before doing any of it.

**Check out the `baseline` branch before running it.** It runs `git reset --hard` on whatever
branch is currently checked out, so running it on `main` discards main.

To land on a different tag:

```bash
./reset.sh ep01-opus-run
```

## Layout

```
requirements.txt        pinned Python dependencies
reset.sh                return to a tagged starting state
analytics/
  CLAUDE.md             instructions for an agent working in this project
  CONVENTIONS.md        the team's warehouse standards. Read this first.
  landing/              files as delivered, one folder per source system
  incoming/             files that have not been moved into landing yet
  models/               staging and marts
  macros/, tests/       custom tests
```

## Running it

```bash
cd analytics
dbt build
```

Sources read the files in `landing/` directly through a wildcard, so there is nothing to load
first. Drop a new dated file into the right folder and the next run picks it up.

## Tags

| Tag | State |
|---|---|
| `ep01-baseline` | Starting state. Landing zone, empty dbt project, conventions. |
| `ep01-opus-run` | Sources, staging models, macros and tests. |
| `ep01-sources`, `ep01-staging`, `ep01-staging-fixed` | Earlier states, kept for reference. |

`git diff ep01-baseline ep01-opus-run` shows everything that was added.
