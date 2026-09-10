# Instructions for agents

This file is the cross-tool convention (`AGENTS.md`). Claude Code additionally reads `CLAUDE.md`,
which carries the same content for this repository.

## What this repository is

A companion repository for a video series on agentic AI for data analytics. Each episode lives in
its own directory under `episodes/` and stands alone. Code is written to be read by someone
learning, so clarity beats cleverness.

## Working on a dbt project here

**The dbt projects have their own instructions. Read them before writing anything.** Each one has an
`AGENTS.md` in its root. Follow it, and any files it points to.

## Setting up an environment

Each episode directory is self-contained and pins its own dependencies.

```bash
cd episodes/<episode-directory>
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

See the episode's own `README.md` for anything specific to it.

## Constraints

1. **Local first.** DuckDB, a script, a scheduler, a folder of markdown files. No framework enters
   this repository until an episode explicitly argues that the problem earned it.
2. **Must reproduce on a clean machine.** No cloud warehouse account, no paid tooling, no signup
   wall. Pin versions rather than floating them.
3. **Spell out every acronym on first use.** The audience is assumed to know none of them.
4. **One directory per episode, each standing alone.** Duplication is preferable to a reader having
   to follow three directories to understand one episode.

## Writing style

- No em-dashes anywhere: prose, docstrings, comments, commit messages.
- Number ranges as "3 to 4", not with a dash.
- Plain English. Concise means fewer words, not denser jargon.

## Commit messages

Describe what changed structurally, never what it is meant to teach, show or prove. Write "Add branch
reference data", not "add the file that makes the join fail". The same applies to file
comments, script headers and README prose.

## Do not

- Rewrite history behind a tag once an episode has published.
- Edit files in a `landing/` directory. Those are inputs, treated as immutable.
