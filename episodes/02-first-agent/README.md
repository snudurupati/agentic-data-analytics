# Episode 2: From ChatGPT to your first coding agent

This episode is for data engineers and analytics engineers who already use SQL, Python, and dbt, but still copy code from a chatbot into their project by hand.

The demo uses Codex on camera. The repository and task are not tied to Codex. The same task can be run with Claude Code, Gemini CLI, OpenCode, or another coding-agent harness that can read files, edit files, and run a terminal command.

## What the words mean

- A model is the reasoning engine that generates a response.
- A chatbot gives the model a conversation interface. It normally returns text for you to copy.
- A coding-agent harness connects a model to tools such as file reading, file editing, and terminal commands.
- An agent is the model using those tools in a loop to complete a stated task and check the result.
- Orchestration coordinates multiple agents, tasks, or handoffs. It is not needed for this episode.

## What you need

- Python 3.12.
- One coding-agent harness installed and signed in.
- A terminal.
- Git is optional. You can clone the repository with Git or download the repository as a ZIP file from GitHub.

You need only one agent tool. Follow its official installation instructions because these commands change over time:

- Codex CLI: https://learn.chatgpt.com/docs/codex/cli
- Claude Code: https://docs.anthropic.com/en/docs/claude-code/getting-started
- Gemini CLI: https://geminicli.com/docs/
- OpenCode: https://opencode.ai/docs/

## 1. Get the project

With Git:

```bash
git clone https://github.com/snudurupati/agentic-data-analytics.git
cd agentic-data-analytics/episodes/02-first-agent
```

Without Git, download the repository ZIP from GitHub, extract it, and open `episodes/02-first-agent` in a terminal.

## 2. Build and verify the baseline

macOS or Linux:

```bash
python3.12 scripts/setup_demo.py
```

Windows PowerShell:

```powershell
py -3.12 scripts/setup_demo.py
```

The Windows path is designed to be equivalent but has not yet been verified on a Windows machine. The macOS clean-directory path was verified on 2026-08-28.

The setup script creates an isolated Python environment, installs the pinned dbt and DuckDB versions, proves that dbt can connect, runs the selected dbt build, and records a local snapshot for later review. It does not install an agent tool.

The final message must say `Baseline ready.` before you continue.

## 3. Start your coding agent

Open the `analytics` directory first:

```bash
cd analytics
```

Then start one installed tool:

```text
Codex CLI    codex
Claude Code  claude
Gemini CLI   gemini
OpenCode     opencode
```

The tools use different permission controls. Before the task, confirm that the tool is working only in this project and that it will ask before any command you do not expect. Do not enable unrestricted or bypass-permission modes for this demo.

## 4. Give the same task to any tool

Paste this prompt exactly:

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

The prompt names the shared instruction file directly, so it does not depend on whether a tool automatically reads `AGENTS.md`, `CLAUDE.md`, or `GEMINI.md`.

## 5. Review what changed

Leave the agent, return to the Episode 2 directory, and run:

macOS or Linux:

```bash
cd ..
.venv/bin/python scripts/demo.py review
```

Windows PowerShell:

```powershell
cd ..
.venv\Scripts\python scripts\demo.py review
```

The review command prints the names of changed, added, and deleted files, then shows the exact line changes in `_staging.yml`. It works even when the project came from a ZIP file and has no Git history.

The expected result is one modified file. Stop if the agent changed, added, or deleted anything else.

## 6. Run the check yourself

macOS or Linux:

```bash
.venv/bin/python scripts/demo.py check
```

Windows PowerShell:

```powershell
.venv\Scripts\python scripts\demo.py check
```

This independently runs `dbt build --select stg_pos__transactions`. The agent's summary is not the evidence. The command and its result are.

## 7. Reset the demo

macOS or Linux:

```bash
.venv/bin/python scripts/demo.py reset
```

Windows PowerShell:

```powershell
.venv\Scripts\python scripts\demo.py reset
```

The reset command restores only the file this demo allowed the agent to change and removes generated dbt output. It does not delete unexpected changes. If the review reports another changed file, inspect it or start again from a fresh clone or ZIP extraction.

## What makes this repeatable

- Python, dbt, and DuckDB versions are pinned.
- The warehouse runs locally with no cloud account.
- The input files are committed and immutable.
- The same prompt works across coding-agent harnesses.
- Setup records a local before-state, so review does not require Git knowledge.
- Review, verification, and reset are separate from the agent's own claims.
