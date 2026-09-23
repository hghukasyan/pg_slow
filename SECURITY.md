# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 0.1.x | Yes |

## Scope

`pg_slow` is a read-only SQL helper over `pg_stat_statements`. It must never execute captured query text, modify plans, or terminate sessions.

## Reporting a vulnerability

Please open a private security advisory on the GitHub repository, or email the maintainers if advisories are unavailable. Include PostgreSQL version, extension version, and a minimal reproduction.
