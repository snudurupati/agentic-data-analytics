# Project instructions

Read `CONVENTIONS.md` and `STANDARDS.md` before changing this dbt project.

`CONVENTIONS.md` contains business facts that cannot be inferred from the data. `STANDARDS.md` defines how models and tests are built here.

## Working rules

- Treat every file under `landing/` as an immutable input.
- Keep changes inside this `analytics` directory.
- Use the existing pinned dependencies. Do not install or add a package unless the task explicitly requests it.
- Run dbt with `../.venv/bin/dbt` on macOS or Linux and `..\.venv\Scripts\dbt.exe` on Windows.
- The project is a Git checkout. Use Git only to inspect the current branch and working-tree changes unless the task explicitly requests another Git action.
- Run only the narrowest dbt command that verifies the named task.
- Do not commit, push, or connect to a production warehouse unless the task explicitly requests it.
- Report every file changed and every verification command run.
