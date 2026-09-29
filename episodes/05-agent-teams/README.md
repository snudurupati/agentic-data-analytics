# Episode 5: Build the pipeline with an agent team

This episode is for data engineers and analytics engineers who gave one agent a complete build in
Episode 4. Here the same build goes to a team of agents that work in parallel, and every message
they send each other is printed as it is sent.

The build is the same as Episode 4: sources, staging models, dimensions, facts and the reports
the business asked for. What changes is who builds it. A lead agent plans the work and splits it.
One teammate takes each source system, and one more builds the marts.

The recorded demo uses agent teams in Claude Code. Agent teams are experimental and are off by
default. They need an interactive session: they do not start from a script or from `claude -p`.

## The four context documents

Every document sits in the `analytics` directory. Every agent reads all four. The prompt repeats
none of them.

| File | What it holds |
|---|---|
| `AGENTS.md` | The working rules, and the instruction to read the other three |
| `CONVENTIONS.md` | The business rules |
| `STANDARDS.md` | How a model is built here |
| `REQUIREMENTS.md` | What the business needs to see, and what each number means |

Two things changed since Episode 4. `REQUIREMENTS.md` names the report tables and their columns,
and states which sales daily branch sales includes. `STANDARDS.md` states that a mart publishes the
numerator and the denominator of a rate, not the rate.

## Prerequisites

You need:

- Git.
- Python 3.12.
- A terminal.
- `tmux`, installed as described below.
- Claude Code, installed and signed in.

### Install tmux

`tmux` is a terminal multiplexer. It splits one terminal window into panes, and the agent team
gives each teammate its own pane. It is a system tool, not a Python package, so
`requirements.txt` does not install it.

| System | Command |
|---|---|
| macOS, with Homebrew | `brew install tmux` |
| Ubuntu or Debian | `sudo apt install tmux` |
| Windows | Use WSL (Windows Subsystem for Linux), then the Ubuntu command |

Check the install:

```bash
tmux -V
```

The lesson assumes that you already know SQL and dbt. It explains every Git command it asks you
to run.

## Setup with an agent

Open your agent in a directory where it may create the repository, then paste this prompt. It
prepares the environment. It does not build the pipeline.

```text
Clone https://github.com/snudurupati/agentic-data-analytics.git into a new folder named ada-ep05.
Use git clone --no-checkout.

Inside the clone, run git sparse-checkout set episodes/05-agent-teams.

Start at the ep05-baseline tag.
Create and switch to a new branch named ep05-demo.

Read episodes/05-agent-teams/README.md.
Follow its environment setup instructions.

Build the environment with Python 3.12.
If a virtual environment is active, deactivate it first.
Find the real Python 3.12 interpreter.
Use its absolute path to create .venv.

Confirm the Python version with .venv/bin/python --version.
Install exactly the versions listed in requirements.txt.

From episodes/05-agent-teams/analytics, run ../.venv/bin/dbt debug.

Run git status --short and git branch --show-current.
Report their output.

Only set up the environment.
Do not create or change models, sources, tests, or macros.
Do not change the landing files or the Markdown files.
Do not commit or push.
```

A clean setup reports Python 3.12, `All checks passed!`, and the branch `ep05-demo`.
`git status --short` prints nothing. Close that session before you start the team.

## Watch the board

A team keeps its state in plain files under `~/.claude`: one inbox per agent, and a task list.
Claude Code removes the team folder when the session ends.

`tools/board.py` prints every new message between the agents as it arrives, and appends each one
to a log file that stays after the session ends. It uses the Python standard library only.

Open a second terminal and start it before the team exists:

```bash
cd ada-ep05/episodes/05-agent-teams
python3 tools/board.py --log board.log
```

What it prints is what the agents said to each other. It is not their reasoning.

## Start the team

In the first terminal, run these three commands one at a time.

Start a `tmux` session named `ep05`:

```bash
tmux new -s ep05
```

Move into the dbt project:

```bash
cd ada-ep05/episodes/05-agent-teams/analytics
```

Start Claude Code with agent teams switched on:

```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --teammate-mode tmux
```

`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` switches on agent teams for this one session. They are
off by default. `--teammate-mode tmux` gives each teammate its own `tmux` pane, so every agent's
work is visible at once.

Check that a team folder exists before you paste anything. In a third terminal:

```bash
ls ~/.claude/teams
```

One `session-...` folder means agent teams are on.

## Run the build

Paste this once. Do not send a second prompt until it finishes.

```text
Read AGENTS.md first.
Read CONVENTIONS.md, STANDARDS.md, and REQUIREMENTS.md.
Inspect the project and the files under landing/.

Build this warehouse from the landing files through to the data marts.
Deliver the reports that REQUIREMENTS.md asks for.
Use an agent team.

Plan the work before any teammate writes a file.
Write the plan to reports/TEAM_PLAN.md.
Put each piece of work on the shared task list.
State which tasks depend on other tasks.

Spawn one teammate for each source system under landing/.
Name each teammate after its source system.
Spawn one more teammate named marts.
The marts teammate starts when the staging tasks it needs are complete.

Each teammate owns its own files.
Two teammates never edit the same file.
The lead owns the files that every teammate needs.
When a teammate needs a change to a file it does not own, it sends a message to the owner.
When a teammate makes a decision that another teammate depends on, it sends that teammate a message.

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

When every task is complete, run dbt build for the complete project.
Fix implementation errors and rerun the relevant checks.

Finish with a report.
State the teammates you spawned and the tasks each one completed.
State the files you created and the files you changed.
State the number of sources, staging models, intermediate models, marts, and tests.
Include the final dbt build result line.
List every business decision you could not make.
List every rule or assumption you relied on that is not stated in the four documents.
List every message between teammates that changed a teammate's work.
Write the whole report to reports/BUILD_REPORT.md as well.
```

An agent team uses more tokens than one session, because every teammate is a separate session.
Check `/usage` in the lead's window when it finishes.

## Review what changed with Git

From the `analytics` directory:

```bash
git status --short
git diff HEAD -- landing/ AGENTS.md CONVENTIONS.md STANDARDS.md REQUIREMENTS.md
```

The second command prints nothing when the source data and the four documents are unchanged. If
it prints anything, stop and read it.

## Run the check yourself

Still in the `analytics` directory:

```bash
../.venv/bin/dbt build
```

Run it even though the lead already ran it. The lead's summary is not evidence. The dbt output is.

## Read the board and the report together

The report lists the messages that changed a teammate's work. The board log has every message
that was captured. Compare the two.

## Load the next batch of files

`test-data/pos/` holds the next night of point-of-sale files. Copy them into the landing zone and
run the pipeline again:

```bash
cp ../test-data/pos/transaction_20260723*.csv landing/pos/
../.venv/bin/dbt build
```

No model is edited and no prompt is sent.

## Reset and repeat

```bash
git restore .
git clean -n
```

`git restore .` returns every tracked file to the branch state. `git clean -n` lists the
untracked files without deleting them. Read the list, then run `git clean -f`. A fresh clone is
always a safe restart. After a session, `tmux kill-server` closes any panes left open.

## What makes this repeatable

- The starting state is the immutable `ep05-baseline` Git tag.
- Every viewer works on a separate `ep05-demo` branch.
- Python, dbt and DuckDB versions are pinned.
- The warehouse runs locally with no cloud account.
- The input files are committed and treated as immutable.
- The board log keeps a record of the messages after the team is gone.
- The dbt check is run independently of the lead's final message.
