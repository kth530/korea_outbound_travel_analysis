-- name: route_raw_counts
SELECT 'raw_route_passenger' AS table_name, COUNT(*) AS row_count FROM raw_route_passenger
UNION ALL SELECT 'raw_route_operations', COUNT(*) FROM raw_route_operations;

-- name: route_raw_columns
SELECT table_name, ordinal_position, column_name, column_type, is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name IN ('raw_route_passenger', 'raw_route_operations')
ORDER BY table_name, ordinal_position;

-- name: route_raw_quality
SELECT 'passengers' AS metric, COUNT(*) AS rows_count, COUNT(DISTINCT period_raw) AS periods,
       SUM(passengers IS NULL) AS null_values, SUM(passengers = 0) AS zero_values,
       SUM(origin_airport_raw = '전체 합계') AS aggregate_rows
FROM raw_route_passenger
UNION ALL
SELECT 'operations', COUNT(*), COUNT(DISTINCT period_raw),
       SUM(operations IS NULL), SUM(operations = 0),
       SUM(origin_airport_raw = '전체 합계')
FROM raw_route_operations;

-- name: route_raw_total_parity
WITH detail AS (
    SELECT 'passengers' AS metric, period_raw,
           MAX(CASE WHEN origin_airport_raw = '전체 합계' THEN passengers END) AS reported_total,
           SUM(CASE WHEN origin_airport_raw <> '전체 합계' THEN passengers END) AS detail_total
    FROM raw_route_passenger GROUP BY period_raw
    UNION ALL
    SELECT 'operations', period_raw,
           MAX(CASE WHEN origin_airport_raw = '전체 합계' THEN operations END),
           SUM(CASE WHEN origin_airport_raw <> '전체 합계' THEN operations END)
    FROM raw_route_operations GROUP BY period_raw
)
SELECT metric, period_raw, reported_total, detail_total,
       reported_total - detail_total AS difference
FROM detail ORDER BY metric, period_raw;
