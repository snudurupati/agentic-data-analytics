# analytics

A dbt project over a landing zone of files from four source systems: a CRM, an ERP, an e-commerce
platform, and point-of-sale terminals in eight branches.

Runs on dbt Core with DuckDB. No cloud account, no warehouse, nothing behind a signup wall.

## Before you build anything

**Read [`CONVENTIONS.md`](CONVENTIONS.md) and [`STANDARDS.md`](STANDARDS.md).**

`CONVENTIONS.md` holds the business rules: what each feed is, who owns it, how the business treats corrections, deletions and reporting periods. Most of it is not discoverable by looking at the data.

`STANDARDS.md` holds how we build: layers, required columns, grain, testing, definition of done.

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
