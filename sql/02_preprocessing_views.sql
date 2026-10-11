-- 국내 공항 참조로 국제선 범위를 판별한다. 원문은 raw에 보존하고 뷰에서만 공백·괄호를 표준화한다.

-- name: create_v_domestic_airport_reference
-- 한국공항공사 공항 목록(https://www.airport.co.kr/booking/ajaxf/frTrafficGoodsSvc/getAvailAirportList.do)과
-- 인천국제공항공사(https://www.airport.kr/ap_ko/index.do)를 기준으로 만든 국내 공항 참조 뷰다.
-- 원문 집계에 실제로 등장한 공항만 쓰지 않아, 국제선 실적이 없는 국내 공항도 포함한다.
CREATE OR REPLACE VIEW v_domestic_airport_reference AS
SELECT '김포' AS destination_std, '김포' AS airport_canonical_std, 'GMP' AS airport_code,
       'KAC official airport list' AS reference_source
UNION ALL SELECT '김해', '김해', 'PUS', 'KAC official airport list'
UNION ALL SELECT '대구', '대구', 'TAE', 'KAC official airport list'
UNION ALL SELECT '무안', '무안', 'MWX', 'KAC official airport list'
UNION ALL SELECT '양양', '양양', 'YNY', 'KAC official airport list'
UNION ALL SELECT '울산', '울산', 'USN', 'KAC official airport list'
UNION ALL SELECT '인천', '인천', 'ICN', 'IIAC official airport list'
UNION ALL SELECT '제주', '제주', 'CJU', 'KAC official airport list'
UNION ALL SELECT '청주', '청주', 'CJJ', 'KAC official airport list'
UNION ALL SELECT '광주', '광주', 'KWJ', 'KAC official airport list'
UNION ALL SELECT '여수', '여수', 'RSU', 'KAC official airport list'
UNION ALL SELECT '포항경주', '포항경주', 'KPO', 'KAC official airport list'
UNION ALL SELECT '사천', '사천', 'HIN', 'KAC official airport list'
UNION ALL SELECT '군산', '군산', 'KUV', 'KAC official airport list'
UNION ALL SELECT '원주', '원주', 'WJU', 'KAC official airport list';

-- name: create_v_route_monthly
-- 노선 여객·운항 통계를 NULL-safe 전체 조인하고, 국내선 형태 예외 행을 삭제하지 않은 채 범위를 표시한다.
CREATE OR REPLACE VIEW v_route_monthly AS
WITH passenger_rows AS (
    SELECT origin_airport_raw, destination_airport_raw, period_raw, passengers, 1 AS passenger_exists
    FROM raw_route_passenger
    WHERE origin_airport_raw <> '전체 합계'
), operation_rows AS (
    SELECT origin_airport_raw, destination_airport_raw, period_raw, operations
    FROM raw_route_operations
    WHERE origin_airport_raw <> '전체 합계'
), combined AS (
    SELECT p.origin_airport_raw, p.destination_airport_raw, p.period_raw,
           CASE
               WHEN TRIM(p.period_raw) REGEXP '^[0-9]{4}년[[:space:]]*[0-9]{1,2}월$'
                AND CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(p.period_raw), '년', -1), '월', 1)) AS UNSIGNED)
                    BETWEEN 1 AND 12
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
                AND CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(o.period_raw), '년', -1), '월', 1)) AS UNSIGNED)
                    BETWEEN 1 AND 12
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
       CASE route_scope_std
           WHEN 'international' THEN TRUE
           WHEN 'domestic' THEN FALSE
           ELSE NULL
       END AS is_international
FROM scoped;


-- name: route_view_row_parity
SELECT (SELECT COUNT(*) FROM raw_route_passenger WHERE origin_airport_raw <> '전체 합계') AS passenger_detail_rows,
       (SELECT COUNT(*) FROM v_route_monthly WHERE passengers IS NOT NULL) AS passenger_view_rows,
       (SELECT COUNT(*) FROM raw_route_operations WHERE origin_airport_raw <> '전체 합계') AS operation_detail_rows,
       (SELECT COUNT(*) FROM v_route_monthly WHERE operations IS NOT NULL) AS operation_view_rows;

-- name: route_view_total_parity
WITH raw_total AS (
    SELECT 'passengers' AS metric, period_raw, SUM(passengers) AS value_ FROM raw_route_passenger
    WHERE origin_airport_raw <> '전체 합계' GROUP BY period_raw
    UNION ALL
    SELECT 'operations', period_raw, SUM(operations) FROM raw_route_operations
    WHERE origin_airport_raw <> '전체 합계' GROUP BY period_raw
), view_total AS (
    SELECT 'passengers' AS metric, period_raw, SUM(passengers) AS value_ FROM v_route_monthly GROUP BY period_raw
    UNION ALL
    SELECT 'operations', period_raw, SUM(operations) FROM v_route_monthly GROUP BY period_raw
)
SELECT r.metric, r.period_raw, r.value_ AS raw_total, v.value_ AS view_total,
       r.value_ - v.value_ AS difference
FROM raw_total AS r JOIN view_total AS v USING (metric, period_raw)
ORDER BY r.metric, r.period_raw;

-- name: route_scope_summary
SELECT route_scope_std, COUNT(*) AS rows_count,
       SUM(COALESCE(passengers,0)) AS passengers,
       SUM(COALESCE(operations,0)) AS operations
FROM v_route_monthly GROUP BY route_scope_std ORDER BY route_scope_std;

-- name: destination_name_collisions
SELECT destination_airport_std, COUNT(DISTINCT destination_airport_raw) AS raw_names,
       GROUP_CONCAT(DISTINCT destination_airport_raw ORDER BY destination_airport_raw SEPARATOR ' | ') AS examples
FROM v_route_monthly WHERE destination_airport_std IS NOT NULL
GROUP BY destination_airport_std HAVING COUNT(DISTINCT destination_airport_raw)>1
ORDER BY raw_names DESC, destination_airport_std;

-- name: monthly_period_parse_check
SELECT COUNT(*) AS rows_count, SUM(period_ym IS NULL) AS invalid_period_rows,
       MIN(period_ym) AS first_period, MAX(period_ym) AS last_period,
       COUNT(DISTINCT period_ym) AS periods
FROM v_route_monthly;

-- name: route_scope_monthly_comparison
-- 국제선 범위 적용 전후 월별 합계와 제외·미확정 값을 비교한다.
SELECT period_ym,
       SUM(COALESCE(passengers, 0)) AS all_passengers,
       SUM(CASE WHEN is_international = TRUE THEN COALESCE(passengers, 0) ELSE 0 END) AS international_passengers,
       SUM(CASE WHEN route_scope_std = 'domestic' THEN COALESCE(passengers, 0) ELSE 0 END) AS domestic_exception_passengers,
       SUM(CASE WHEN route_scope_std = 'unresolved' THEN COALESCE(passengers, 0) ELSE 0 END) AS unresolved_passengers,
       SUM(COALESCE(operations, 0)) AS all_operations,
       SUM(CASE WHEN is_international = TRUE THEN COALESCE(operations, 0) ELSE 0 END) AS international_operations,
       SUM(CASE WHEN route_scope_std = 'domestic' THEN COALESCE(operations, 0) ELSE 0 END) AS domestic_exception_operations,
       SUM(CASE WHEN route_scope_std = 'unresolved' THEN COALESCE(operations, 0) ELSE 0 END) AS unresolved_operations
FROM v_route_monthly
GROUP BY period_ym
ORDER BY period_ym;
