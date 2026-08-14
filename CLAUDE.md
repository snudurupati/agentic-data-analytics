# Agentic AI for Data Analytics: working notes for Claude

Companion repository for a video series aimed at data engineers and analytics engineers who have
never built anything agentic.

## What this repository is optimised for

**Someone reading the code after watching the video.** Clarity beats cleverness every time. If a
shorter, denser version exists, do not use it. The audience is strong at SQL and dbt and new to
this, so the code has to be legible to a person who is learning, not impressive to a person who
already knows.

## Non-negotiables

1. **Local first.** DuckDB, a script, a scheduler, a folder of markdown files. No framework enters
   this repository until an episode explicitly argues that the problem earned it. Episodes 5 and 8
   are entire arguments against premature frameworks, so importing LangChain for convenience in
   episode 3 would be self-defeating.
2. **Demos must reproduce on a clean machine.** No cloud warehouse account, no paid tooling, no
   signup wall. If an episode needs a model API key, its README says so and says what the run cost.
3. **Nothing is rigged.** Whatever happens on camera is what happened. Retries stay in. Anything
   staged is obvious within ten seconds to anyone who has done this work.
4. **Spell out every acronym on first use** in any README or comment. MCP, RAG, SFR, all of them.
   The audience is assumed to know none of them.
5. **One directory per episode, and each stands alone.** Shared code goes in `shared/` only when
   two episodes genuinely need it. Duplication is preferable to a viewer having to read three
   directories to follow one episode.

## Writing style

- **No em-dashes.** Anywhere. Not in prose, not in docstrings, not in comments, not in commit
  messages. Use commas, parentheses, semicolons, or split the sentence.
- Number ranges as "3 to 4", not with a dash.
- Plain English. Concise means fewer words, not denser jargon.

## Commit messages describe structure, never intent

Write "Add POS transaction seed", not "add the seed that demonstrates late arrivals". Describe what
changed structurally. Never describe what it is meant to teach, show or prove.

The same applies to file comments, script headers and README prose.

## Tags

Every episode gets a tag (`ep01`, `ep02`, and so on) at the state shown on screen. Do not rewrite
history behind a tag once an episode has published, because viewers are checking it out.

## Related repositories

None currently. Episode 1 is self-contained.
