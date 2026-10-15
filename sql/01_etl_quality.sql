-- scripts/route_etl.py가 적재한 분석 테이블의 읽기 전용 검산.

-- name: etl_fact_counts
SELECT '2023_2025_route' AS fact_name, COUNT(*) AS rows_count,
       MIN(period_ym) AS first_period, MAX(period_ym) AS last_period
FROM etl_route_monthly_2023_2025
UNION ALL
SELECT '2026_route', COUNT(*), MIN(period_ym), MAX(period_ym)
FROM etl_route_monthly_2026
UNION ALL
SELECT 'destination_monthly', COUNT(*), MIN(period_ym), MAX(period_ym)
FROM etl_destination_monthly_all
UNION ALL
SELECT 'destination_profile', COUNT(*), MIN(first_period), MAX(last_period)
FROM etl_destination_profile;

-- name: etl_route_scope_summary
SELECT '2023_2025' AS source_period, route_scope_std,
       COUNT(*) AS rows_count,
       SUM(COALESCE(passengers, 0)) AS passengers,
       SUM(COALESCE(operations, 0)) AS operations
FROM etl_route_monthly_2023_2025
GROUP BY route_scope_std
UNION ALL
SELECT '2026', route_scope_std, COUNT(*),
       SUM(COALESCE(passengers, 0)), SUM(COALESCE(operations, 0))
FROM etl_route_monthly_2026
GROUP BY route_scope_std;

-- name: etl_monthly_parity
WITH route AS (
    SELECT period_ym, SUM(passengers) AS passengers, SUM(operations) AS operations
    FROM (
        SELECT period_ym, passengers, operations
        FROM etl_route_monthly_2023_2025 WHERE is_international = 1
        UNION ALL
        SELECT period_ym, passengers, operations
        FROM etl_route_monthly_2026 WHERE is_international = 1
    ) AS combined
    GROUP BY period_ym
), destination AS (
    SELECT period_ym, SUM(passengers) AS passengers, SUM(operations) AS operations
    FROM etl_destination_monthly_all GROUP BY period_ym
)
SELECT route.period_ym,
       route.passengers - destination.passengers AS passenger_difference,
       route.operations - destination.operations AS operation_difference
FROM route JOIN destination USING (period_ym)
ORDER BY route.period_ym;

-- name: etl_quality_counts
SELECT '2023_2025' AS source_period,
       SUM(period_ym IS NULL) AS invalid_period_rows,
       SUM(route_scope_std = 'unresolved') AS unresolved_scope_rows,
       SUM(passengers IS NULL) AS missing_passenger_rows,
       SUM(operations IS NULL) AS missing_operation_rows
FROM etl_route_monthly_2023_2025
UNION ALL
SELECT '2026', SUM(period_ym IS NULL), SUM(route_scope_std = 'unresolved'),
       SUM(passengers IS NULL), SUM(operations IS NULL)
FROM etl_route_monthly_2026;
