# Episode 3: Project context

This episode is for data engineers and analytics engineers who have run a coding agent on a
small task (Episode 2) and want to see what changes when the agent builds something new in a
project.

The task is the same in both halves of the episode: declare one source and build its staging
model. The two halves start from two tags. `ep03-baseline` is the project as a fresh checkout.
`ep03-baseline-context` is the same project plus two documents, `CONVENTIONS.md` and
`STANDARDS.md`, in the `analytics` directory. Nothing else differs:

```bash
git diff ep03-baseline ep03-baseline-context --stat
```

## Prerequisites

Same as Episode 2: Git, Python 3.12, a terminal, and one coding-agent harness installed and
signed in. The lesson assumes SQL, Python and dbt.

## One new Git command: sparse checkout

This repository holds every episode. For this episode, only the Episode 3 folder should be on
disk. `git sparse-checkout` answers the question "which folders do I want in my working tree?"
The other episodes stay in Git history and are not checked out.

## Setup by hand, run A (no context documents)

```bash
git clone --no-checkout https://github.com/snudurupati/agentic-data-analytics.git ada-a
cd ada-a
git sparse-checkout set episodes/03-project-context
git switch -c ep03-a ep03-baseline
cd episodes/03-project-context
/opt/homebrew/bin/python3.12 -m venv .venv
.venv/bin/python --version
.venv/bin/python -m pip install -r requirements.txt
cd analytics
../.venv/bin/dbt debug
git status --short
```

`--no-checkout` clones the history without writing files. `sparse-checkout set` names the one
folder to write. `git switch -c ep03-a ep03-baseline` creates the working branch at the tag.
`dbt debug` should report that the profile and connection are valid. `git status --short` should
print nothing.

## Setup by hand, run B (with context documents)

The same commands with two names changed:

```bash
git clone --no-checkout https://github.com/snudurupati/agentic-data-analytics.git ada-b
cd ada-b
git sparse-checkout set episodes/03-project-context
git switch -c ep03-b ep03-baseline-context
cd episodes/03-project-context
/opt/homebrew/bin/python3.12 -m venv .venv
.venv/bin/python --version
.venv/bin/python -m pip install -r requirements.txt
cd analytics
../.venv/bin/dbt debug
git status --short
```

Use two separate clones. The agent in run A must not be able to read the files from run B.

## Setup with an agent, run A

Open your agent in the folder where it may create the repository, then paste this.

```text
Clone https://github.com/snudurupati/agentic-data-analytics.git into a new
folder named ada-a, using git clone --no-checkout.

Inside it, run git sparse-checkout set episodes/03-project-context so that only
that folder is written to disk.

Start at the ep03-baseline tag. Create and switch to a new branch named ep03-a.

Read episodes/03-project-context/README.md and follow it to build the
environment.

Build the environment with Python 3.12. If a virtual environment is active,
deactivate it first. Find the real Python 3.12 interpreter and use its absolute
path to create .venv. Do not rely on the python3.12 command on PATH because a
different environment may replace it.

After creating the environment, use .venv/bin/python --version to confirm that
it is Python 3.12. Then install exactly the versions listed in requirements.txt.

From episodes/03-project-context/analytics, use:

../.venv/bin/dbt debug

Finally, use git status --short and git branch --show-current. Tell me what they
print. A clean setup should not change a tracked file.

Only set up the environment. Do not create or change a model, source, test, or
macro. Do not commit. Do not change anything under landing/.
```

## Setup with an agent, run B

The same request with three names changed.

```text
Clone https://github.com/snudurupati/agentic-data-analytics.git into a new
folder named ada-b, using git clone --no-checkout.

Inside it, run git sparse-checkout set episodes/03-project-context so that only
that folder is written to disk.

Start at the ep03-baseline-context tag. Create and switch to a new branch named
ep03-b.

Read episodes/03-project-context/README.md and follow it to build the
environment.

Build the environment with Python 3.12. If a virtual environment is active,
deactivate it first. Find the real Python 3.12 interpreter and use its absolute
path to create .venv. Do not rely on the python3.12 command on PATH because a
different environment may replace it.

After creating the environment, use .venv/bin/python --version to confirm that
it is Python 3.12. Then install exactly the versions listed in requirements.txt.

From episodes/03-project-context/analytics, use:

../.venv/bin/dbt debug

Finally, use git status --short and git branch --show-current. Tell me what they
print. A clean setup should not change a tracked file.

Only set up the environment. Do not create or change a model, source, test, or
macro. Do not commit. Do not change anything under landing/.
```

Use two separate folders. The agent in run A must not be able to read run B.

## The task

Open the harness on the `analytics` directory of one clone and paste the task. Use the same text
for run A and run B.

```text
Read AGENTS.md first.

Declare the CRM accounts source and build its staging model.

Put the source declaration and the staging model under models/staging.

Add tests for the staging model.

Do not modify a file under landing/.

Run the narrowest dbt command that verifies your work.

Do not commit.
```

## Find what the repository cannot tell you

Run this in the run A clone, after the task. It is the prompt that produces your own starting
list on your own repository.

```text
List the facts about this business that you cannot determine from this repository.
```

Pick one item from the list. Write it as a single fact in a new `CONVENTIONS.md` in the
`analytics` directory. State the fact and stop. Do not state the consequence, and do not name
the implementation.

Then start a fresh run A clone that has only that one-rule `CONVENTIONS.md`, paste the task
prompt again, and compare the result with your first run A.

## Review what changed

From the `analytics` directory:

```bash
git status --short
git diff
```

Then run the check yourself:

```bash
../.venv/bin/dbt build --select models/staging
```

The agent's summary is not evidence. The dbt output is.

## Compare the two runs

From each clone's `analytics` directory, save the diff to a file outside the repository, then
compare the two files side by side in your editor.

## Reset and repeat

```bash
git restore .
git clean -n
```

`git restore .` returns every tracked file to the branch state. `git clean -n` lists untracked
files the agent created without deleting them. Read the list. Then run `git clean -f` to remove
them, or start from a fresh clone, which is always the safe restart.
