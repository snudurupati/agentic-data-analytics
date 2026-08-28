# Episode 2: From ChatGPT to your first coding agent

This episode is for data engineers and analytics engineers who already use SQL, Python, and dbt, but still copy code from a chatbot into their project by hand.

The recorded demo uses Codex in the ChatGPT desktop app. The repository and task are not tied to Codex. The same prompt can be used with Claude Code, Gemini CLI, OpenCode, or another coding-agent harness that can read files, edit files, and run terminal commands.

## What the words mean

- A model is the reasoning engine that generates a response.
- A chatbot gives the model a conversation interface. It normally returns text for you to copy.
- A coding-agent harness connects a model to project files, editing tools, terminal commands, permissions, and Git.
- An agent is the model using those tools in a loop to complete a task and check the result.
- Orchestration coordinates multiple agents, tasks, or handoffs. It is not needed for this episode.

## Prerequisites

You need:

- Git.
- Python 3.12.
- A terminal.
- One coding-agent harness installed and signed in.

The lesson assumes that you already know SQL, Python, and dbt. It explains every Git command it asks you to run.

For the recorded path, install the ChatGPT desktop app and use Codex. Other supported examples are Claude Code, Gemini CLI, and OpenCode. Follow each tool's official installation instructions because they change over time.

## Setup with an agent

Episode 1 used an agent to prepare its own local environment. Episode 2 follows the same pattern. Open your agent in a directory where it may create the repository, then paste this prompt:

```text
Clone https://github.com/snudurupati/agentic-data-analytics.git into a new
directory called ada.

Then read AGENTS.md at the repository root and
episodes/02-first-agent/README.md, and follow them to build the environment
for episode 2.

Start from the ep02-baseline tag and create a new branch called ep02-demo.

Build the environment with Python 3.12. If a virtual environment is already
active, deactivate it first, and use an absolute path to the interpreter rather
than whatever python3.12 resolves to on PATH, because an unrelated environment
can shadow it. After creating the environment, confirm with
.venv/bin/python --version that it really is Python 3.12. Then install exactly
the pinned versions in requirements.txt.

From the analytics directory, verify the environment with:

../.venv/bin/dbt debug
../.venv/bin/dbt build --select stg_pos__transactions

Finally, run git status --short and tell me which branch I am on. Explain any
status output. A clean setup should not change a tracked file.

Set up the environment only. Do not fix the declared grain tests, do not write
or modify a model, test, or macro, do not commit, and do not modify anything
under landing/.
```

The final paragraph prevents the setup task from turning into the episode task.

## Setup by hand

Clone the repository, create a working branch from the recorded baseline, and enter the episode directory:

```bash
git clone https://github.com/snudurupati/agentic-data-analytics.git ada
cd ada
git switch -c ep02-demo ep02-baseline
cd episodes/02-first-agent
```

`git switch -c ep02-demo ep02-baseline` creates a new branch named `ep02-demo` at the recorded starting point. Your work is isolated from `main`, and the baseline tag remains unchanged.

Create the pinned Python environment on macOS or Linux:

```bash
/opt/homebrew/bin/python3.12 -m venv .venv
.venv/bin/python --version
source .venv/bin/activate
python -m pip install -r requirements.txt
```

If Python 3.12 is somewhere else, use `which -a python3.12` to find its absolute path. The version command must report Python 3.12.

On Windows PowerShell:

```powershell
py -3.12 -m venv .venv
.venv\Scripts\python.exe --version
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

The Windows commands have not yet been verified on a Windows machine.

Verify the baseline on macOS or Linux:

```bash
cd analytics
../.venv/bin/dbt debug
../.venv/bin/dbt build --select stg_pos__transactions
git status --short
```

The dbt build should finish with five passing checks. `git status --short` should print nothing because setup and dbt output are ignored by Git.

## Run the task in the Codex app

1. Open the ChatGPT desktop app and select Codex.
2. Open the local folder `ada/episodes/02-first-agent/analytics`.
3. Use the local checkout for this demo so Codex works on the `ep02-demo` branch and uses the environment you just created.
4. Keep the default project sandbox and approval controls. Do not grant access to unrelated folders or enable unrestricted execution.
5. Paste the task below.

```text
Read AGENTS.md, CONVENTIONS.md, and STANDARDS.md first.

Fix the declared grain tests for stg_pos__transactions.

The grain is branch_id and transaction_id together.

Test both columns for null values.

Test the two columns together for uniqueness.

Change only models/staging/_staging.yml.

Do not add a package or a file.

Run dbt build only for stg_pos__transactions.

Do not commit.
```

The prompt names the shared instruction files directly, so it does not depend on which project-context filename a harness loads automatically.

## Run the same task in another harness

Start the harness from the `analytics` directory and paste the same prompt:

```text
Claude Code  claude
Gemini CLI   gemini
OpenCode     opencode
```

Permission labels and user interfaces differ. Keep the project boundary, one-file task, same prompt, same Git review, and same dbt check.

## Review what changed with Git

From the `analytics` directory, run:

```bash
git status --short
git diff -- models/staging/_staging.yml
```

The first command answers, "Which files changed?" In its short output, `M` means modified, `??` means a new untracked file, and `D` means deleted.

The expected result is one modified file: `models/staging/_staging.yml`. Stop if another path appears.

The second command shows the exact lines removed and added. Check that both grain columns are required and that they are tested together for uniqueness.

In the Codex app, the review pane shows the same Git-backed working-tree changes visually. Use it for inspection, but keep the terminal commands in the lesson because they work outside Codex too.

## Run the check yourself

Still in the `analytics` directory, run:

```bash
../.venv/bin/dbt build --select stg_pos__transactions
```

This should finish with six passing checks. Run it yourself even if the agent already ran it. The agent's summary is not evidence.

## Reset and repeat

Restore the one file this task allowed the agent to change:

```bash
git restore models/staging/_staging.yml
git status --short
```

The first command restores the file from the current branch. The second should print nothing.

If `git status --short` reports another modified, deleted, or untracked file, inspect it. Do not use a broad cleanup command until you understand what it would remove. A fresh clone is always a safe restart.

## What makes this repeatable

- The starting state is the immutable `ep02-baseline` Git tag.
- Every viewer works on a separate `ep02-demo` branch.
- Python, dbt, and DuckDB versions are pinned.
- The warehouse runs locally with no cloud account.
- The input files are committed and treated as immutable.
- The same task prompt works across coding-agent harnesses.
- Git records the before-state, shows every change, and restores the permitted file.
- The dbt check is run independently of the agent's final message.
