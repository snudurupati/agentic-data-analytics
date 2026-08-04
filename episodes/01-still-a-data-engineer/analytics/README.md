# analytics

A dbt project over a landing zone of files from four source systems: a CRM, an ERP, an e-commerce
platform, and point-of-sale terminals in eight branches.

Runs on dbt Core with DuckDB. No cloud account, no warehouse, nothing behind a signup wall.

## Before you build anything

**Read [`CONVENTIONS.md`](CONVENTIONS.md).** It covers what a nightly file means for each of the
four systems (they disagree), who owns each feed and what can be asked of them, the audit columns
every table carries, and why we never hard-delete.

Most of it is not discoverable by looking at the data.

## Running it

```bash
dbt build
```

Sources read the files in `landing/` directly through a wildcard, so there is nothing to load
first. Drop a new dated file into the right folder and the next run picks it up.

## Layout

```
landing/    files as delivered, one folder per source system, immutable
models/
  staging/  one model per source table, grouped by system
macros/     custom tests
tests/      singular tests
```
