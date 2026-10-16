# Episode 6: Review the build

This episode is for data engineers and analytics engineers who watched an agent, or a team of agents, build a complete warehouse in Episodes 4 and 5. Here the warehouse is already built. The episode reviews it.

The `analytics` directory holds the dbt project exactly as the Episode 5 agent team built it on camera: 8 sources, 8 staging models, 5 intermediate models, 6 marts and 149 tests, with the team's plan and build report in `analytics/reports/`. No model was edited after the team finished.

This episode has no video. The README and the tag are the whole episode.

## What is in the folder

| Path | What it holds |
|---|---|
| `analytics/AGENTS.md` | The working rules, and the instruction to read the other documents |
| `analytics/CONVENTIONS.md` | The business rules |
| `analytics/STANDARDS.md` | How a model is built here |
| `analytics/REQUIREMENTS.md` | What the business needs to see, and what each number means |
| `analytics/landing/` | The source files, immutable |
| `analytics/models/`, `analytics/tests/`, `analytics/macros/` | The dbt project the team built |
| `analytics/reports/TEAM_PLAN.md` | The team's plan and task list |
| `analytics/reports/BUILD_REPORT.md` | The team's build report |
| `test-data/pos/` | The next night of point-of-sale files, not yet in the landing zone |

## Prerequisites

You need:

- Git.
- Python 3.12.
- A terminal.
- Claude Code, installed and signed in.
- The DuckDB command line, 1.5.5 or later, to query the warehouse yourself.

The lesson assumes that you already know SQL and dbt. It explains every Git command it asks you to run.

## Setup with an agent

Open your agent in a directory where it may create the repository, then paste this prompt. It prepares the environment. It does not change the dbt project.

```text
Clone https://github.com/snudurupati/agentic-data-analytics.git into a new folder named ada-ep06.
Use git clone --no-checkout.

Inside the clone, run git sparse-checkout set episodes/06-review-the-build.

Start at the ep06-baseline tag.
Create and switch to a new branch named ep06-demo.

Read episodes/06-review-the-build/README.md.
Follow its environment setup instructions.

Build the environment with Python 3.12.
If a virtual environment is active, deactivate it first.
Find the real Python 3.12 interpreter.
Use its absolute path to create .venv.

Confirm the Python version with .venv/bin/python --version.
Install exactly the versions listed in requirements.txt.

From episodes/06-review-the-build/analytics, run ../.venv/bin/dbt debug.

Run git status --short and git branch --show-current.
Report their output.

Only set up the environment.
Do not create or change models, sources, tests, or macros.
Do not change the landing files or the Markdown files.
Do not commit or push.
```

A clean setup reports Python 3.12, `All checks passed!`, and the branch `ep06-demo`. `git status --short` prints nothing. Close that session before you start.

## Build the warehouse

From the `analytics` directory:

```bash
../.venv/bin/dbt build
```

This builds `analytics.duckdb` from the landing files. It takes a few seconds. No agent is involved.

## Review the build

Three checks, in order. Start Claude Code in the `analytics` directory and run the prompts in one session.

On Claude Opus 5.5 in October 2026, the three prompts together took about 10 to 15 minutes of agent time and cost about $5 to $6.50 at API list prices.

### 1. Check one number against the source files

Open the warehouse read-only with the DuckDB command line, then compare revenue calculated from the raw order line files with the same total from the warehouse:

```bash
duckdb -readonly analytics.duckdb
```

```sql
select round(sum(cast(line_amount as decimal(18,2))), 2) as from_the_files
from (
  select *, row_number() over (
           partition by order_number, line_number order by change_ts desc) as rn
  from read_csv('landing/erp/order_line_*.csv', union_by_name = true, all_varchar = true)
) where rn = 1 and op <> 'D';

select round(sum(line_amount), 2) as order_lines from fct_order_line;
```

### 2. Prove that each test can fail

```text
Read AGENTS.md first.
Read reports/BUILD_REPORT.md.
List the singular tests under tests/.
Prove that each test can fail.
Copy this analytics directory to a temporary directory first.
For each test, change the data in the copy so that the test must return a row.
Run only that test in the copy.
Do not change any file in this directory.
Report each test, the change you made, and the result.
List every test that did not fail.
```

Read the list of tests that did not fail, then open each one next to the model it reads.

### 3. Ask for a business decision

```text
Match the customers across CRM, ERP and e-commerce.
Build one customer list.
```

If the agent does not build the list, ask for the evidence instead:

```text
Do not build it.
List the candidate matches for the sales manager.
Show the evidence for each match.
Write the list to reports/CUSTOMER_MATCHES.md.
```

Check at least one number in that list against the landing files yourself.

## Review what changed with Git

After any agent session, from the `analytics` directory:

```bash
git status --short
git diff HEAD -- landing/ models/ tests/ macros/ AGENTS.md CONVENTIONS.md STANDARDS.md REQUIREMENTS.md
```

The second command prints nothing when the source data, the dbt project and the four documents are unchanged. If it prints anything, stop and read it.

## Reset and repeat

```bash
git restore .
git clean -n
```

`git restore .` returns every tracked file to the branch state. `git clean -n` lists the untracked files without deleting them. Read the list, then run `git clean -f`. A fresh clone is always a safe restart.

## What makes this repeatable

- The starting state is the immutable `ep06-baseline` Git tag.
- Every viewer works on a separate `ep06-demo` branch.
- Python, dbt and DuckDB versions are pinned.
- The warehouse runs locally with no cloud account.
- The input files and the dbt project are committed.
