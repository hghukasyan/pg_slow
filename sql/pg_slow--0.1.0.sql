/* pg_slow--0.1.0.sql
 *
 * Copyright 2026 The pg_slow Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

CREATE FUNCTION pg_slow(
    result_limit integer DEFAULT 10,
    min_calls integer DEFAULT 5
)
RETURNS TABLE (
    queryid bigint,
    query text,
    calls bigint,
    total_exec_time_ms double precision,
    mean_exec_time_ms double precision,
    rows bigint,
    time_share_percent double precision,
    impact_score text
)
LANGUAGE sql
VOLATILE
PARALLEL SAFE
AS $$
    WITH eligible AS (
        SELECT
            s.queryid,
            s.query,
            s.calls,
            s.total_exec_time,
            s.mean_exec_time,
            s.rows
        FROM pg_stat_statements AS s
        WHERE s.calls >= GREATEST(COALESCE(min_calls, 0), 0)
          AND s.queryid IS NOT NULL
    ),
    totals AS (
        SELECT COALESCE(SUM(e.total_exec_time), 0::double precision) AS all_total
        FROM eligible AS e
    )
    SELECT
        e.queryid,
        e.query,
        e.calls,
        e.total_exec_time AS total_exec_time_ms,
        e.mean_exec_time AS mean_exec_time_ms,
        e.rows,
        CASE
            WHEN t.all_total <= 0 THEN 0::double precision
            ELSE round((e.total_exec_time / t.all_total * 100.0)::numeric, 1)::double precision
        END AS time_share_percent,
        CASE
            WHEN t.all_total <= 0 THEN 'LOW'
            WHEN (e.total_exec_time / t.all_total * 100.0) >= 25 THEN 'CRITICAL'
            WHEN (e.total_exec_time / t.all_total * 100.0) >= 10 THEN 'HIGH'
            WHEN (e.total_exec_time / t.all_total * 100.0) >= 3 THEN 'MEDIUM'
            ELSE 'LOW'
        END AS impact_score
    FROM eligible AS e
    CROSS JOIN totals AS t
    ORDER BY e.total_exec_time DESC, e.calls DESC, e.queryid
    LIMIT GREATEST(COALESCE(result_limit, 0), 0);
$$;

COMMENT ON FUNCTION pg_slow(integer, integer) IS
    'Return queries ranked by total execution time from pg_stat_statements';

REVOKE ALL ON FUNCTION pg_slow(integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_slow(integer, integer) TO PUBLIC;
