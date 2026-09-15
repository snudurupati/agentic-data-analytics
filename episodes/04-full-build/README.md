# Episode 4: Build the pipeline

This episode is for data engineers and analytics engineers who have written the context
documents (Episode 3) and want to give an agent a complete build.

The task is one build assignment. The agent declares the sources, builds the staging models,
builds the dimensions and the facts, and builds a daily branch sales mart.

## The four documents

Every document sits in the `analytics` directory.

| File | What it holds |
|---|---|
| `AGENTS.md` | The working rules, and the instruction to read the other three |
| `CONVENTIONS.md` | The business rules |
| `STANDARDS.md` | How a model is built here |
| `REQUIREMENTS.md` | What the business needs to see, and what each number means |

Episode 3 used the first three. `REQUIREMENTS.md` is new. Staging models sit at the grain of
the source, so nothing needed defining. Marts aggregate, so the metrics need a definition.

## Prerequisites

Git, Python 3.12, a terminal, and one coding-agent harness installed and signed in. The lesson
assumes SQL and dbt.

## Setup

This repository holds every episode. Only the Episode 4 folder is needed on disk.

```bash
git clone --no-checkout https://github.com/snudurupati/agentic-data-analytics.git ada-ep04
cd ada-ep04
git sparse-checkout set episodes/04-full-build
git switch -c ep04-demo ep04-baseline
cd episodes/04-full-build
/opt/homebrew/bin/python3.12 -m venv .venv
.venv/bin/python --version
.venv/bin/python -m pip install -r requirements.txt
cd analytics
../.venv/bin/dbt debug
git status --short
```

`dbt debug` reports that the profile and the connection are valid. `git status --short` prints
nothing.

## Run the build

Open the agent on the `analytics` directory. The build prompt names the deliverables and the
boundaries. It names no column and no SQL technique. The four documents carry the rest.

## Check the result yourself

From the `analytics` directory:

```bash
../.venv/bin/dbt build
git status --short
git diff HEAD -- landing/ AGENTS.md CONVENTIONS.md STANDARDS.md REQUIREMENTS.md
```

The agent's summary is not evidence. The dbt output is. The third command prints nothing when
the source data and the four documents are unchanged.

## The second delivery

`test-data/pos/` holds the next night of point-of-sale files. Copy them into
`analytics/landing/pos/` after the first build, then run `dbt build` again. No model changes and
no new prompt. The sources read the folder.

## Reset

```bash
git restore .
git clean -n
```

`git restore .` returns every tracked file to the branch state. `git clean -n` lists the
untracked files without deleting them. Read the list, then run `git clean -f`, or start from a
fresh clone.
