-- Regression tests for pg_slow
-- Requires: shared_preload_libraries = 'pg_stat_statements'
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION pg_slow;

-- ---------------------------------------------------------------------------
-- Extension creation / function shape
-- ---------------------------------------------------------------------------
SELECT extname, extversion
FROM pg_extension
WHERE extname = 'pg_slow';

SELECT
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS args,
    pg_get_function_result(p.oid) AS result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'pg_slow';

-- ---------------------------------------------------------------------------
-- Zero-statistics / division-by-zero behavior
-- With a huge min_calls filter, no rows are eligible: empty set, no error.
-- ---------------------------------------------------------------------------
SELECT pg_stat_statements_reset() IS NOT NULL AS stats_reset_ok;

SELECT count(*) AS zero_eligible_rows
FROM pg_slow(10, 1000000);

-- ---------------------------------------------------------------------------
-- Deterministic load using distinct relations so query jumbling keeps them
-- separate. Identical statement text is repeated so calls accumulate.
-- ---------------------------------------------------------------------------
SELECT pg_stat_statements_reset() IS NOT NULL AS stats_reset_ok;

CREATE TEMP TABLE pg_slow_a (x int);
CREATE TEMP TABLE pg_slow_b (x int);
INSERT INTO pg_slow_a VALUES (1);
INSERT INTO pg_slow_b VALUES (1);

-- Heavy: five top-level calls (~250ms total)
SELECT count(*) FROM (SELECT pg_sleep(0.05) FROM pg_slow_a) s;
SELECT count(*) FROM (SELECT pg_sleep(0.05) FROM pg_slow_a) s;
SELECT count(*) FROM (SELECT pg_sleep(0.05) FROM pg_slow_a) s;
SELECT count(*) FROM (SELECT pg_sleep(0.05) FROM pg_slow_a) s;
SELECT count(*) FROM (SELECT pg_sleep(0.05) FROM pg_slow_a) s;

-- Light: five top-level calls (~50ms total)
SELECT count(*) FROM (SELECT pg_sleep(0.01) FROM pg_slow_b) s;
SELECT count(*) FROM (SELECT pg_sleep(0.01) FROM pg_slow_b) s;
SELECT count(*) FROM (SELECT pg_sleep(0.01) FROM pg_slow_b) s;
SELECT count(*) FROM (SELECT pg_sleep(0.01) FROM pg_slow_b) s;
SELECT count(*) FROM (SELECT pg_sleep(0.01) FROM pg_slow_b) s;

-- Single-call noise for min_calls filtering
SELECT 'x' AS pg_slow_noise;

-- ---------------------------------------------------------------------------
-- Default limit (10) and default min_calls (5)
-- ---------------------------------------------------------------------------
SELECT
    calls >= 5 AS meets_default_min_calls,
    total_exec_time_ms > 0 AS has_time,
    time_share_percent >= 0 AS nonneg_share,
    impact_score IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW') AS valid_impact
FROM pg_slow()
WHERE query LIKE '%pg_slow_a%'
   OR query LIKE '%pg_slow_b%'
ORDER BY query;

-- ---------------------------------------------------------------------------
-- Custom limit
-- ---------------------------------------------------------------------------
SELECT count(*) AS custom_limit_rows
FROM pg_slow(1, 1);

-- ---------------------------------------------------------------------------
-- Minimum calls filter
-- ---------------------------------------------------------------------------
SELECT count(*) AS noise_with_min_calls_5
FROM pg_slow(50, 5)
WHERE query LIKE '%pg_slow_noise%';

SELECT count(*) AS noise_with_min_calls_1
FROM pg_slow(50, 1)
WHERE query LIKE '%pg_slow_noise%';

-- ---------------------------------------------------------------------------
-- Ranking by total_exec_time (not mean)
-- ---------------------------------------------------------------------------
SELECT
    (
        SELECT total_exec_time_ms
        FROM pg_slow(20, 5)
        WHERE query LIKE '%pg_slow_a%'
        LIMIT 1
    )
    >
    (
        SELECT total_exec_time_ms
        FROM pg_slow(20, 5)
        WHERE query LIKE '%pg_slow_b%'
        LIMIT 1
    ) AS heavy_has_more_total_time,
    (
        SELECT row_number
        FROM (
            SELECT
                query,
                row_number() OVER (ORDER BY total_exec_time_ms DESC) AS row_number
            FROM pg_slow(20, 5)
            WHERE query LIKE '%pg_slow_a%'
               OR query LIKE '%pg_slow_b%'
        ) r
        WHERE query LIKE '%pg_slow_a%'
        LIMIT 1
    ) = 1 AS heavy_ranks_first;

-- ---------------------------------------------------------------------------
-- Time share calculation + impact thresholds
-- ---------------------------------------------------------------------------
SELECT
    abs(sum(time_share_percent) - 100.0) < 0.2 AS shares_sum_near_100
FROM pg_slow(100, 5)
WHERE query LIKE '%pg_slow_a%'
   OR query LIKE '%pg_slow_b%';

SELECT
    time_share_percent >= 70 AS dominant_has_majority_share,
    impact_score = 'CRITICAL' AS dominant_is_critical
FROM pg_slow(20, 5)
WHERE query LIKE '%pg_slow_a%'
LIMIT 1;

SELECT
    time_share_percent >= 10 AND time_share_percent < 25 AS light_is_high,
    impact_score = 'HIGH' AS light_impact_high
FROM pg_slow(20, 5)
WHERE query LIKE '%pg_slow_b%'
LIMIT 1;

-- ---------------------------------------------------------------------------
-- Impact threshold: sole eligible statement => 100% => CRITICAL
-- ---------------------------------------------------------------------------
SELECT pg_stat_statements_reset() IS NOT NULL AS stats_reset_ok;

CREATE TEMP TABLE pg_slow_solo (x int);
INSERT INTO pg_slow_solo VALUES (1);

SELECT count(*) FROM (SELECT pg_sleep(0.02) FROM pg_slow_solo) s;
SELECT count(*) FROM (SELECT pg_sleep(0.02) FROM pg_slow_solo) s;
SELECT count(*) FROM (SELECT pg_sleep(0.02) FROM pg_slow_solo) s;
SELECT count(*) FROM (SELECT pg_sleep(0.02) FROM pg_slow_solo) s;
SELECT count(*) FROM (SELECT pg_sleep(0.02) FROM pg_slow_solo) s;

SELECT
    time_share_percent = 100 AS sole_query_is_100_percent,
    impact_score = 'CRITICAL' AS sole_query_is_critical,
    calls = 5 AS sole_query_call_count
FROM pg_slow(5, 5)
WHERE query LIKE '%pg_slow_solo%'
LIMIT 1;

-- Cleanup
DROP EXTENSION pg_slow;
