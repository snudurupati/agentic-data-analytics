# Episode 4: Build the pipeline

This episode is for data engineers and analytics engineers who wrote the context documents in
Episode 3 and want to give an agent a complete build.

The task is one build assignment. The agent declares the sources, builds the staging models,
builds the dimensions and the facts, and builds the reports the business asked for.

The recorded demo uses Claude Code. The repository and the task are not tied to it. The same
prompts work with Codex, Gemini CLI, OpenCode, or another coding-agent harness that can read
files, edit files, and run terminal commands.

## The four context documents

Every document sits in the `analytics` directory. The agent reads all four. The prompt repeats
none of them.

| File | What it holds |
|---|---|
| `AGENTS.md` | The working rules, and the instruction to read the other three |
| `CONVENTIONS.md` | The business rules |
| `STANDARDS.md` | How a model is built here |
| `REQUIREMENTS.md` | What the business needs to see, and what each number means |

Episode 3 used the first three. `REQUIREMENTS.md` is new here. A staging model sits at the grain
of its source, so nothing needed defining. A mart aggregates, so the metrics need a definition.

## Prerequisites

You need:

- Git.
- Python 3.12.
- A terminal.
- One coding-agent harness installed and signed in.

The lesson assumes that you already know SQL and dbt. It explains every Git command it asks you
to run.

## Setup with an agent

Open your agent in a directory where it may create the repository, then paste this prompt. It
prepares the environment. It does not build the pipeline.

```text
Clone https://github.com/snudurupati/agentic-data-analytics.git into a new folder named ada-ep04.
Use git clone --no-checkout.

Inside the clone, run git sparse-checkout set episodes/04-full-build.

Start at the ep04-baseline tag.
Create and switch to a new branch named ep04-demo.

Read episodes/04-full-build/README.md.
Follow its environment setup instructions.

Build the environment with Python 3.12.
If a virtual environment is active, deactivate it first.
Find the real Python 3.12 interpreter.
Use its absolute path to create .venv.

Confirm the Python version with .venv/bin/python --version.
Install exactly the versions listed in requirements.txt.

From episodes/04-full-build/analytics, run ../.venv/bin/dbt debug.

Run git status --short and git branch --show-current.
Report their output.

Only set up the environment.
Do not create or change models, sources, tests, or macros.
Do not change the landing files or the Markdown files.
Do not commit or push.
```

The last paragraph stops the setup task from turning into the episode task.

A clean setup reports Python 3.12, `All checks passed!`, and the branch `ep04-demo`.
`git status --short` prints nothing.

## Why the clone contains only one folder

This repository holds every episode. `git sparse-checkout` writes only the Episode 4 folder to
disk. The other episodes stay in Git history.

## Run the build

Open your harness on the `analytics` directory:

```
ada-ep04/episodes/04-full-build/analytics
```

Paste this once. Do not send a second prompt until it finishes.

```text
Read AGENTS.md first.
Read CONVENTIONS.md, STANDARDS.md, and REQUIREMENTS.md.
Inspect the project and the files under landing/.

Build this warehouse from the landing files through to the data marts.
Deliver the reports that REQUIREMENTS.md asks for.

Declare sources for every feed under landing/.
Build the staging models for those sources.
Load each feed incrementally. Follow the feed type in CONVENTIONS.md.
Add intermediate models if a mart needs them.

Use the business rules in CONVENTIONS.md.
Follow the build standards in STANDARDS.md.
State the grain of every model.
Add the tests required by those documents.

If a missing business decision blocks part of the build, report it.
Continue with the parts that do not depend on that decision.
Do not invent a business rule to finish the build.

Keep changes inside this analytics directory.
Do not modify the landing files or the existing Markdown files.
Use the existing pinned dependencies.
Do not commit or push.

Run dbt build for the complete project.
Fix implementation errors and rerun the relevant checks.

Finish with a report.
State the files you created and the files you changed.
State the number of sources, staging models, intermediate models, marts, and tests.
State the checks you ran and their results.
Include the final dbt build result line.
List any model you left incomplete.
List every business decision you could not make.
List every rule or assumption you relied on that is not stated in AGENTS.md,
CONVENTIONS.md, STANDARDS.md, or REQUIREMENTS.md.
Include modelling conventions you chose yourself.
Explain how to run the pipeline again when more files arrive.
```

The prompt names the deliverables and the boundaries. It names no column, no table and no SQL
technique. The four documents carry the rest. The last block is the part most people skip: it
asks the agent to list what it relied on that nobody wrote down.

## Review what changed with Git

From the `analytics` directory:

```bash
git status --short
git diff HEAD -- landing/ AGENTS.md CONVENTIONS.md STANDARDS.md REQUIREMENTS.md
```

In the short output, `??` means a new untracked file and `M` means a tracked file was modified.
Expect many `??` entries and one `M` on `dbt_project.yml`, because the agent has to set how each
layer is materialised.

The second command prints nothing when the source data and the four documents are unchanged. If
it prints anything, stop and read it.

## Run the check yourself

Still in the `analytics` directory:

```bash
../.venv/bin/dbt build
```

Run it even though the agent already ran it. The agent's summary is not evidence. The dbt output
is.

## Read the last section of the agent's report

The build passing tells you the SQL ran. It does not tell you what the agent decided on your
behalf. The report lists every rule it relied on that is not in the four documents. Read that
list before you read any SQL.

## Load the next batch of files

Nothing so far has proved the pipeline handles a delivery it has not already seen. Both nights of
files were present before the first build ran.

`test-data/pos/` holds the next night of point-of-sale files, held back for this. Copy them into
the landing zone and run the pipeline again:

```bash
cp ../test-data/pos/transaction_20260723*.csv landing/pos/
../.venv/bin/dbt build
```

No model is edited and no prompt is sent. That is the point.

**Why it works without editing anything.** Each source reads its whole folder through a wildcard,
so a new dated file is picked up on the next run with nothing to register. Each staging model is
incremental: it loads only the files it has not loaded before, and appends the rows that differ
from the rows already held. Running again with no new files adds nothing.

**What this delivery contains.** It is one night from the tills, and it carries the cases
`CONVENTIONS.md` describes: a refund as its own transaction with a negative amount, at the branch
that processed it rather than the branch that made the sale; a void sent as a zero-amount row
reusing a transaction id; the same transaction id issued by two different branches on the same
night; and one branch pushing a second file behind its first.

Check that the pipeline handled each of them. The row counts, the branch-day totals and the
warning tests are where they show up.

## Reset and repeat

```bash
git restore .
git clean -n
```

`git restore .` returns every tracked file to the branch state. `git clean -n` lists the
untracked files without deleting them. Read the list, then run `git clean -f`. A fresh clone is
always a safe restart.

## What makes this repeatable

- The starting state is the immutable `ep04-baseline` Git tag.
- Every viewer works on a separate `ep04-demo` branch.
- Python, dbt and DuckDB versions are pinned.
- The warehouse runs locally with no cloud account.
- The input files are committed and treated as immutable.
- The same prompts work across coding-agent harnesses.
- Git records the before-state and shows every change.
- The dbt check is run independently of the agent's final message.
