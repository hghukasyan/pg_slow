# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-09-22

### Added

- Initial release of `pg_slow` for PostgreSQL 14+.
- SQL function `pg_slow(result_limit integer DEFAULT 10, min_calls integer DEFAULT 5)`.
- Ranking by `total_exec_time` from `pg_stat_statements`.
- `time_share_percent` and `impact_score` (`CRITICAL` / `HIGH` / `MEDIUM` / `LOW`).
- PGXS build, regression tests, and Apache-2.0 license.
