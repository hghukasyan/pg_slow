# Contributing to pg_slow

Thanks for helping. `pg_slow` stays intentionally small: a read-only SQL utility on top of `pg_stat_statements`.

## Ground rules

- Prefer pure SQL / PLpgSQL and PGXS.
- Do not add monitoring platforms, HTTP APIs, daemons, collectors, or auto-optimizers.
- Keep the default API: `pg_slow()`, `pg_slow(limit)`, `pg_slow(limit, min_calls)`.
- Ranking must remain by **total** execution time, not mean latency.
- Do not execute captured query text, change plans, or kill sessions.

## Development setup

1. PostgreSQL 14+ with `pg_stat_statements` available.
2. Set in `postgresql.conf` (and restart):

   ```conf
   shared_preload_libraries = 'pg_stat_statements'
   ```

3. Build and install:

   ```sh
   make
   make install
   ```

4. Run regression tests:

   ```sh
   make installcheck
   ```

## Pull requests

- Keep diffs focused and easy to review.
- Update `expected/pg_slow.out` when intentional test output changes.
- Update `README.md` / `CHANGELOG.md` when behavior or docs change.
- Add a short note explaining *why* the change is needed.

## Reporting bugs

Include:

- PostgreSQL version (`SELECT version();`)
- `pg_slow` version (`SELECT extversion FROM pg_extension WHERE extname = 'pg_slow';`)
- Whether `pg_stat_statements` is loaded (`SHOW shared_preload_libraries;`)
- The exact SQL you ran and the error or unexpected result

## License

By contributing, you agree that your contributions are licensed under the Apache License 2.0.
