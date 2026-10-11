-- 2026-01~07 노선 여객·운항 2개 Excel의 독립 적재 및 월별 범위.
-- 모델 패널은 sql/05의 정적 뷰, 기준월 피처는 scripts/feature_layer.py.

-- name: create_raw_route_passenger_2026
CREATE TABLE IF NOT EXISTS raw_route_passenger_2026 (
    origin_airport_raw VARCHAR(100) NOT NULL,
    destination_airport_raw VARCHAR(100) NULL,
    period_raw VARCHAR(20) NOT NULL,
    passengers BIGINT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- name: create_raw_route_operations_2026
CREATE TABLE IF NOT EXISTS raw_route_operations_2026 (
    origin_airport_raw VARCHAR(100) NOT NULL,
    destination_airport_raw VARCHAR(100) NULL,
    period_raw VARCHAR(20) NOT NULL,
    operations BIGINT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- name: create_v_route_monthly_2026
-- 02와 같은 규칙으로 여객·운항을 결합하고 공항명을 표준화한다.
CREATE OR REPLACE VIEW v_route_monthly_2026 AS
WITH passenger_rows AS (
    SELECT origin_airport_raw, destination_airport_raw, period_raw, passengers, 1 AS passenger_exists
    FROM raw_route_passenger_2026
    WHERE origin_airport_raw <> '전체 합계'
), operation_rows AS (
    SELECT origin_airport_raw, destination_airport_raw, period_raw, operations
    FROM raw_route_operations_2026
    WHERE origin_airport_raw <> '전체 합계'
), combined AS (
    SELECT p.origin_airport_raw, p.destination_airport_raw, p.period_raw,
           CASE
               WHEN TRIM(p.period_raw) REGEXP '^[0-9]{4}년[[:space:]]*[0-9]{1,2}월$'
                AND CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(p.period_raw), '년', -1), '월', 1)) AS UNSIGNED) BETWEEN 1 AND 12
               THEN CONCAT(LEFT(TRIM(p.period_raw), 4), LPAD(CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(p.period_raw), '년', -1), '월', 1)) AS UNSIGNED), 2, '0'))
           END AS period_ym,
           p.passengers, o.operations
    FROM passenger_rows AS p
    LEFT JOIN operation_rows AS o
      ON p.origin_airport_raw <=> o.origin_airport_raw
     AND p.destination_airport_raw <=> o.destination_airport_raw
     AND p.period_raw <=> o.period_raw
    UNION ALL
    SELECT o.origin_airport_raw, o.destination_airport_raw, o.period_raw,
           CASE
               WHEN TRIM(o.period_raw) REGEXP '^[0-9]{4}년[[:space:]]*[0-9]{1,2}월$'
                AND CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(o.period_raw), '년', -1), '월', 1)) AS UNSIGNED) BETWEEN 1 AND 12
               THEN CONCAT(LEFT(TRIM(o.period_raw), 4), LPAD(CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(o.period_raw), '년', -1), '월', 1)) AS UNSIGNED), 2, '0'))
           END,
           p.passengers, o.operations
    FROM operation_rows AS o
    LEFT JOIN passenger_rows AS p
      ON p.origin_airport_raw <=> o.origin_airport_raw
     AND p.destination_airport_raw <=> o.destination_airport_raw
     AND p.period_raw <=> o.period_raw
    WHERE p.passenger_exists IS NULL
), standardized AS (
    SELECT c.*,
           NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(c.origin_airport_raw), '\\([^)]*\\)', ''), '[[:space:]/_-]', ''), '') AS origin_airport_std,
           NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(c.destination_airport_raw), '\\([^)]*\\)', ''), '[[:space:]/_-]', ''), '') AS destination_airport_std
    FROM combined AS c
), scoped AS (
    SELECT s.*,
           CASE
               WHEN s.origin_airport_std IS NULL OR s.destination_airport_std IS NULL THEN 'unresolved'
               WHEN o.destination_std IS NOT NULL AND d.destination_std IS NOT NULL THEN 'domestic'
               WHEN o.destination_std IS NOT NULL AND d.destination_std IS NULL THEN 'international'
               ELSE 'unresolved'
           END AS route_scope_std
    FROM standardized AS s
    LEFT JOIN v_domestic_airport_reference AS o ON s.origin_airport_std = o.destination_std
    LEFT JOIN v_domestic_airport_reference AS d ON s.destination_airport_std = d.destination_std
)
SELECT scoped.*,
       CASE route_scope_std WHEN 'international' THEN TRUE WHEN 'domestic' THEN FALSE ELSE NULL END AS is_international
FROM scoped;


-- name: route_2026_join_integrity_check
SELECT
    (SELECT COUNT(*) FROM raw_route_passenger_2026 WHERE origin_airport_raw <> '전체 합계') AS passenger_detail_rows,
    (SELECT COUNT(*) FROM v_route_monthly_2026 WHERE passengers IS NOT NULL) AS passenger_view_rows,
    (SELECT COUNT(*) FROM raw_route_operations_2026 WHERE origin_airport_raw <> '전체 합계') AS operation_detail_rows,
    (SELECT COUNT(*) FROM v_route_monthly_2026 WHERE operations IS NOT NULL) AS operation_view_rows,
    SUM(period_ym IS NULL) AS invalid_period_rows,
    SUM(route_scope_std = 'unresolved') AS unresolved_scope_rows
FROM v_route_monthly_2026;
