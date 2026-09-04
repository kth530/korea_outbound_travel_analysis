-- name: table_counts
SELECT 'raw_route_passenger' AS table_name, COUNT(*) AS row_count FROM raw_route_passenger
UNION ALL SELECT 'raw_route_operations', COUNT(*) FROM raw_route_operations
UNION ALL SELECT 'raw_airline_passenger', COUNT(*) FROM raw_airline_passenger
UNION ALL SELECT 'raw_airline_operations', COUNT(*) FROM raw_airline_operations
UNION ALL SELECT 'raw_airport_passenger', COUNT(*) FROM raw_airport_passenger
UNION ALL SELECT 'raw_country_passenger', COUNT(*) FROM raw_country_passenger
UNION ALL SELECT 'raw_departure_flight', COUNT(*) FROM raw_departure_flight;

-- name: table_columns
SELECT table_name AS raw_table_name, ordinal_position AS column_order,
       column_name AS raw_column_name, column_type AS mysql_type, is_nullable AS null_allowed
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name IN (
      'raw_route_passenger', 'raw_route_operations',
      'raw_airline_passenger', 'raw_airline_operations',
      'raw_airport_passenger', 'raw_country_passenger', 'raw_departure_flight'
  )
ORDER BY table_name, ordinal_position;

-- name: aggregate_quality_summary
-- 월간 집계 원본의 기간·수치 결측·0값 현황을 카탈로그로 남긴다.
SELECT 'route_passenger' AS dataset, COUNT(*) AS rows_count,
       MIN(period_raw) AS first_period, MAX(period_raw) AS last_period,
       COUNT(DISTINCT period_raw) AS period_count,
       SUM(passengers IS NULL) AS metric_nulls, SUM(passengers = 0) AS metric_zeros
FROM raw_route_passenger
UNION ALL
SELECT 'route_operations', COUNT(*), MIN(period_raw), MAX(period_raw), COUNT(DISTINCT period_raw),
       SUM(operations IS NULL), SUM(operations = 0)
FROM raw_route_operations
UNION ALL
SELECT 'airline_passenger', COUNT(*), MIN(period_raw), MAX(period_raw), COUNT(DISTINCT period_raw),
       SUM(passengers IS NULL), SUM(passengers = 0)
FROM raw_airline_passenger
UNION ALL
SELECT 'airline_operations', COUNT(*), MIN(period_raw), MAX(period_raw), COUNT(DISTINCT period_raw),
       SUM(operations IS NULL), SUM(operations = 0)
FROM raw_airline_operations
UNION ALL
SELECT 'airport_passenger', COUNT(*), MIN(period_raw), MAX(period_raw), COUNT(DISTINCT period_raw),
       SUM(passengers IS NULL), SUM(passengers = 0)
FROM raw_airport_passenger
UNION ALL
SELECT 'country_passenger', COUNT(*), MIN(period_raw), MAX(period_raw), COUNT(DISTINCT period_raw),
       SUM(passengers IS NULL), SUM(passengers = 0)
FROM raw_country_passenger;

-- name: period_values
-- 이후 2026년 자료가 추가됐을 때 월별 적재 범위를 확인한다.
SELECT 'route_passenger' AS dataset, period_raw, COUNT(*) AS rows_count
FROM raw_route_passenger GROUP BY period_raw
UNION ALL SELECT 'route_operations', period_raw, COUNT(*) FROM raw_route_operations GROUP BY period_raw
UNION ALL SELECT 'airline_passenger', period_raw, COUNT(*) FROM raw_airline_passenger GROUP BY period_raw
UNION ALL SELECT 'airline_operations', period_raw, COUNT(*) FROM raw_airline_operations GROUP BY period_raw
UNION ALL SELECT 'airport_passenger', period_raw, COUNT(*) FROM raw_airport_passenger GROUP BY period_raw
UNION ALL SELECT 'country_passenger', period_raw, COUNT(*) FROM raw_country_passenger GROUP BY period_raw
ORDER BY dataset, period_raw;

-- name: aggregate_row_profile
-- 분석용 월간 뷰에서 제외할 원본 집계 행의 표기와 건수를 확인한다.
SELECT
    'raw_route_passenger' AS table_name,
    origin_airport_raw AS aggregate_value,
    COUNT(*) AS rows_count
FROM raw_route_passenger
WHERE origin_airport_raw = '전체 합계'
GROUP BY origin_airport_raw
UNION ALL
SELECT
    'raw_route_operations' AS table_name,
    origin_airport_raw AS aggregate_value,
    COUNT(*) AS rows_count
FROM raw_route_operations
WHERE origin_airport_raw = '전체 합계'
GROUP BY origin_airport_raw
UNION ALL
SELECT
    'raw_airline_passenger' AS table_name,
    airline_name_raw AS aggregate_value,
    COUNT(*) AS rows_count
FROM raw_airline_passenger
WHERE airline_name_raw IN ('국적사 계', '외항사 계', '전체 합계')
GROUP BY airline_name_raw
UNION ALL
SELECT
    'raw_airline_operations' AS table_name,
    airline_name_raw AS aggregate_value,
    COUNT(*) AS rows_count
FROM raw_airline_operations
WHERE airline_name_raw IN ('국적사 계', '외항사 계', '전체 합계')
GROUP BY airline_name_raw
UNION ALL
SELECT
    'raw_airport_passenger' AS table_name,
    airport_name_raw AS aggregate_value,
    COUNT(*) AS rows_count
FROM raw_airport_passenger
WHERE airport_name_raw = '전체 합계'
GROUP BY airport_name_raw
UNION ALL
SELECT
    'raw_country_passenger' AS table_name,
    region_raw AS aggregate_value,
    COUNT(*) AS rows_count
FROM raw_country_passenger
WHERE region_raw = '전체 합계'
GROUP BY region_raw
ORDER BY table_name, aggregate_value;

-- name: aggregate_row_completeness_check
-- 원본 합계 행과 세부 행 합을 독립적으로 대조해 제외 규칙을 검증한다.
WITH monthly_checks AS (
    SELECT 'airline_passenger' AS dataset, period_raw,
           MAX(CASE WHEN airline_name_raw = '전체 합계' THEN passengers END) AS reported_total,
           SUM(CASE WHEN airline_name_raw NOT IN ('국적사 계', '외항사 계', '전체 합계') THEN passengers END) AS parts_total,
           MAX(CASE WHEN airline_name_raw = '국적사 계' THEN passengers END)
             + MAX(CASE WHEN airline_name_raw = '외항사 계' THEN passengers END) AS subtotal_sum,
           TRUE AS subtotal_applicable
    FROM raw_airline_passenger
    GROUP BY period_raw
    UNION ALL
    SELECT 'airline_operations', period_raw,
           MAX(CASE WHEN airline_name_raw = '전체 합계' THEN operations END),
           SUM(CASE WHEN airline_name_raw NOT IN ('국적사 계', '외항사 계', '전체 합계') THEN operations END),
           MAX(CASE WHEN airline_name_raw = '국적사 계' THEN operations END)
             + MAX(CASE WHEN airline_name_raw = '외항사 계' THEN operations END),
           TRUE
    FROM raw_airline_operations
    GROUP BY period_raw
    UNION ALL
    SELECT 'route_passenger', period_raw,
           MAX(CASE WHEN origin_airport_raw = '전체 합계' THEN passengers END),
           SUM(CASE WHEN origin_airport_raw <> '전체 합계' THEN passengers END),
           NULL, FALSE
    FROM raw_route_passenger
    GROUP BY period_raw
    UNION ALL
    SELECT 'route_operations', period_raw,
           MAX(CASE WHEN origin_airport_raw = '전체 합계' THEN operations END),
           SUM(CASE WHEN origin_airport_raw <> '전체 합계' THEN operations END),
           NULL, FALSE
    FROM raw_route_operations
    GROUP BY period_raw
    UNION ALL
    SELECT 'airport_passenger', period_raw,
           MAX(CASE WHEN airport_name_raw = '전체 합계' THEN passengers END),
           SUM(CASE WHEN airport_name_raw <> '전체 합계' THEN passengers END),
           NULL, FALSE
    FROM raw_airport_passenger
    GROUP BY period_raw
    UNION ALL
    SELECT 'country_passenger', period_raw,
           MAX(CASE WHEN region_raw = '전체 합계' THEN passengers END),
           SUM(CASE WHEN region_raw <> '전체 합계' THEN passengers END),
           NULL, FALSE
    FROM raw_country_passenger
    GROUP BY period_raw
)
SELECT dataset,
       COUNT(*) AS month_count,
       SUM(reported_total IS NULL) AS reported_total_missing_months,
       SUM(NOT (reported_total <=> parts_total)) AS total_mismatch_months,
       SUM(subtotal_applicable AND (subtotal_sum IS NULL OR NOT (reported_total <=> subtotal_sum)))
           AS subtotal_mismatch_months,
       MIN(parts_total - reported_total) AS min_parts_difference,
       MAX(parts_total - reported_total) AS max_parts_difference,
       CASE
           WHEN SUM(reported_total IS NULL) = 0
            AND SUM(NOT (reported_total <=> parts_total)) = 0
            AND SUM(subtotal_applicable AND (subtotal_sum IS NULL OR NOT (reported_total <=> subtotal_sum))) = 0
           THEN 'matched' ELSE 'check'
       END AS completeness_check
FROM monthly_checks
GROUP BY dataset
ORDER BY dataset;

-- name: aggregate_label_discovery
-- 알려진 리터럴 외의 NULL·소계 후보를 발견하며, 결과는 확인 후 판단한다.
SELECT 'route_passenger_origin' AS field_name, origin_airport_raw AS raw_value, COUNT(*) AS rows_count
FROM raw_route_passenger
WHERE origin_airport_raw IS NULL OR origin_airport_raw LIKE '%계%' OR origin_airport_raw LIKE '%소계%'
GROUP BY origin_airport_raw
UNION ALL
SELECT 'route_passenger_destination', destination_airport_raw, COUNT(*)
FROM raw_route_passenger
WHERE destination_airport_raw IS NULL OR destination_airport_raw LIKE '%계%' OR destination_airport_raw LIKE '%소계%'
GROUP BY destination_airport_raw
UNION ALL
SELECT 'route_operations_origin', origin_airport_raw, COUNT(*)
FROM raw_route_operations
WHERE origin_airport_raw IS NULL OR origin_airport_raw LIKE '%계%' OR origin_airport_raw LIKE '%소계%'
GROUP BY origin_airport_raw
UNION ALL
SELECT 'route_operations_destination', destination_airport_raw, COUNT(*)
FROM raw_route_operations
WHERE destination_airport_raw IS NULL OR destination_airport_raw LIKE '%계%' OR destination_airport_raw LIKE '%소계%'
GROUP BY destination_airport_raw
UNION ALL
SELECT 'airline_passenger_name', airline_name_raw, COUNT(*)
FROM raw_airline_passenger
WHERE airline_name_raw IS NULL OR airline_name_raw LIKE '%계%' OR airline_name_raw LIKE '%소계%'
GROUP BY airline_name_raw
UNION ALL
SELECT 'airline_operations_name', airline_name_raw, COUNT(*)
FROM raw_airline_operations
WHERE airline_name_raw IS NULL OR airline_name_raw LIKE '%계%' OR airline_name_raw LIKE '%소계%'
GROUP BY airline_name_raw
UNION ALL
SELECT 'airport_name', airport_name_raw, COUNT(*)
FROM raw_airport_passenger
WHERE airport_name_raw IS NULL OR airport_name_raw LIKE '%계%' OR airport_name_raw LIKE '%소계%'
GROUP BY airport_name_raw
UNION ALL
SELECT 'country_region', region_raw, COUNT(*)
FROM raw_country_passenger
WHERE region_raw IS NULL OR region_raw LIKE '%계%' OR region_raw LIKE '%소계%'
GROUP BY region_raw
UNION ALL
SELECT 'country_name', country_raw, COUNT(*)
FROM raw_country_passenger
WHERE country_raw IS NULL OR country_raw LIKE '%계%' OR country_raw LIKE '%소계%'
GROUP BY country_raw
ORDER BY field_name, rows_count DESC, raw_value;

-- name: flight_number_profile
-- 편명 결측·형식 분포는 해석적 변환 전의 적재 품질 점검이다.
WITH flight_number_flags AS (
    SELECT flight_number_raw,
           CASE
               WHEN flight_number_raw IS NULL OR TRIM(flight_number_raw) = '' THEN 'null_or_blank'
               WHEN TRIM(flight_number_raw) REGEXP '^[A-Za-z]{2}[0-9]+$' THEN 'two_letter_number'
               WHEN TRIM(flight_number_raw) REGEXP '^[A-Za-z]{3}[0-9]+$' THEN 'three_letter_number'
               ELSE 'other'
           END AS flight_number_format
    FROM raw_departure_flight
)
SELECT flight_number_format, COUNT(*) AS rows_count,
       COUNT(DISTINCT NULLIF(TRIM(flight_number_raw), '')) AS distinct_flight_number_count,
       SUBSTRING_INDEX(
           GROUP_CONCAT(DISTINCT NULLIF(TRIM(flight_number_raw), '')
                        ORDER BY NULLIF(TRIM(flight_number_raw), '') SEPARATOR ', '),
           ', ', 10
       ) AS example_flight_numbers
FROM flight_number_flags
GROUP BY flight_number_format
ORDER BY FIELD(flight_number_format, 'null_or_blank', 'two_letter_number', 'three_letter_number', 'other');

-- name: flight_duplicate_candidates
-- 삭제 판단이 아닌 공항·일자·편명·계획시간 기준의 비파괴적 중복 후보 점검이다.
WITH duplicate_groups AS (
    SELECT airport_name_raw, flight_date_raw, flight_number_raw, scheduled_time_raw,
           COUNT(*) AS duplicate_rows
    FROM raw_departure_flight
    GROUP BY airport_name_raw, flight_date_raw, flight_number_raw, scheduled_time_raw
    HAVING COUNT(*) > 1
), duplicate_summary AS (
    SELECT COUNT(*) AS duplicate_group_count, SUM(duplicate_rows) AS duplicate_row_count
    FROM duplicate_groups
), duplicate_examples AS (
    SELECT * FROM duplicate_groups
    ORDER BY duplicate_rows DESC, airport_name_raw, flight_date_raw, flight_number_raw, scheduled_time_raw
    LIMIT 30
)
SELECT 'summary' AS result_type, NULL AS airport_name_raw, NULL AS flight_date_raw,
       NULL AS flight_number_raw, NULL AS scheduled_time_raw, NULL AS duplicate_rows,
       s.duplicate_group_count, s.duplicate_row_count
FROM duplicate_summary AS s
UNION ALL
SELECT 'example', airport_name_raw, flight_date_raw, flight_number_raw, scheduled_time_raw,
       duplicate_rows, NULL, NULL
FROM duplicate_examples;

-- name: flight_date_profile
-- 일자 원문값의 형식·실재 날짜 여부와 적재 기간을 공항별로 확인한다.
SELECT airport_name_raw,
       COUNT(*) AS total_rows,
       SUM(flight_date_raw IS NULL OR TRIM(flight_date_raw) = '') AS date_null_or_blank,
       SUM(flight_date_raw IS NOT NULL AND TRIM(flight_date_raw) <> ''
           AND TRIM(flight_date_raw) NOT REGEXP '^[0-9]{8}$') AS date_format_invalid,
       SUM(TRIM(flight_date_raw) REGEXP '^[0-9]{8}$'
           AND STR_TO_DATE(TRIM(flight_date_raw), '%Y%m%d') IS NULL) AS date_not_a_real_date,
       MIN(TRIM(flight_date_raw)) AS first_date,
       MAX(TRIM(flight_date_raw)) AS last_date,
       COUNT(DISTINCT TRIM(flight_date_raw)) AS distinct_date_count
FROM raw_departure_flight
GROUP BY airport_name_raw
ORDER BY airport_name_raw;

-- name: log_monthly_overview
SELECT airport_name_raw, LEFT(flight_date_raw, 6) AS operating_month, COUNT(*) AS rows_count
FROM raw_departure_flight
GROUP BY airport_name_raw, LEFT(flight_date_raw, 6)
ORDER BY operating_month, airport_name_raw;

-- name: log_status_service
-- 공항·방향·서비스 구분·상태의 원문값 조합을 확인한다.
SELECT airport_name_raw, direction_raw, service_type_raw, status_raw, COUNT(*) AS rows_count
FROM raw_departure_flight
GROUP BY airport_name_raw, direction_raw, service_type_raw, status_raw
ORDER BY airport_name_raw, rows_count DESC, direction_raw, service_type_raw, status_raw;

-- name: log_quality_strict
-- NULL·빈 문자열·':'·형식/시계 범위 오류를 분리해 원본 시간값 품질을 점검한다.
WITH log_flags AS (
    SELECT airport_name_raw,
        scheduled_time_raw IS NULL OR TRIM(scheduled_time_raw) = '' AS scheduled_null_or_blank,
        scheduled_time_raw IS NOT NULL AND TRIM(scheduled_time_raw) = ':' AS scheduled_colon_placeholder,
        scheduled_time_raw IS NOT NULL AND TRIM(scheduled_time_raw) NOT IN ('', ':')
          AND (TRIM(scheduled_time_raw) NOT REGEXP '^[0-9]{1,2}:[0-9]{2}$'
               OR CAST(SUBSTRING_INDEX(TRIM(scheduled_time_raw), ':', 1) AS UNSIGNED) NOT BETWEEN 0 AND 23
               OR CAST(SUBSTRING_INDEX(TRIM(scheduled_time_raw), ':', -1) AS UNSIGNED) NOT BETWEEN 0 AND 59) AS scheduled_invalid_clock,
        estimated_time_raw IS NULL OR TRIM(estimated_time_raw) = '' AS estimated_null_or_blank,
        estimated_time_raw IS NOT NULL AND TRIM(estimated_time_raw) = ':' AS estimated_colon_placeholder,
        estimated_time_raw IS NOT NULL AND TRIM(estimated_time_raw) NOT IN ('', ':')
          AND (TRIM(estimated_time_raw) NOT REGEXP '^[0-9]{1,2}:[0-9]{2}$'
               OR CAST(SUBSTRING_INDEX(TRIM(estimated_time_raw), ':', 1) AS UNSIGNED) NOT BETWEEN 0 AND 23
               OR CAST(SUBSTRING_INDEX(TRIM(estimated_time_raw), ':', -1) AS UNSIGNED) NOT BETWEEN 0 AND 59) AS estimated_invalid_clock,
        actual_departure_time_raw IS NULL OR TRIM(actual_departure_time_raw) = '' AS actual_null_or_blank,
        actual_departure_time_raw IS NOT NULL AND TRIM(actual_departure_time_raw) = ':' AS actual_colon_placeholder,
        actual_departure_time_raw IS NOT NULL AND TRIM(actual_departure_time_raw) NOT IN ('', ':')
          AND (TRIM(actual_departure_time_raw) NOT REGEXP '^[0-9]{1,2}:[0-9]{2}$'
               OR CAST(SUBSTRING_INDEX(TRIM(actual_departure_time_raw), ':', 1) AS UNSIGNED) NOT BETWEEN 0 AND 23
               OR CAST(SUBSTRING_INDEX(TRIM(actual_departure_time_raw), ':', -1) AS UNSIGNED) NOT BETWEEN 0 AND 59) AS actual_invalid_clock
    FROM raw_departure_flight
)
SELECT airport_name_raw, COUNT(*) AS total_rows,
       SUM(scheduled_null_or_blank) AS scheduled_null_or_blank,
       SUM(scheduled_colon_placeholder) AS scheduled_colon_placeholder,
       SUM(scheduled_invalid_clock) AS scheduled_invalid_clock,
       SUM(scheduled_null_or_blank OR scheduled_colon_placeholder OR scheduled_invalid_clock) AS scheduled_unusable,
       SUM(estimated_null_or_blank) AS estimated_null_or_blank,
       SUM(estimated_colon_placeholder) AS estimated_colon_placeholder,
       SUM(estimated_invalid_clock) AS estimated_invalid_clock,
       SUM(estimated_null_or_blank OR estimated_colon_placeholder OR estimated_invalid_clock) AS estimated_unusable,
       SUM(actual_null_or_blank) AS actual_null_or_blank,
       SUM(actual_colon_placeholder) AS actual_colon_placeholder,
       SUM(actual_invalid_clock) AS actual_invalid_clock,
       SUM(actual_null_or_blank OR actual_colon_placeholder OR actual_invalid_clock) AS actual_unusable
FROM log_flags
GROUP BY airport_name_raw
ORDER BY airport_name_raw;

-- name: invalid_time_pattern_profile
-- 형식 오류 시간값의 자릿수와 3자리 H:MM 복원 가능 후보 규모만 확인한다.
WITH invalid_values AS (
    SELECT 'scheduled' AS field_name, TRIM(scheduled_time_raw) AS time_value
    FROM raw_departure_flight
    WHERE scheduled_time_raw IS NOT NULL AND TRIM(scheduled_time_raw) NOT IN ('', ':')
      AND (TRIM(scheduled_time_raw) NOT REGEXP '^[0-9]{1,2}:[0-9]{2}$'
           OR CAST(SUBSTRING_INDEX(TRIM(scheduled_time_raw), ':', 1) AS UNSIGNED) NOT BETWEEN 0 AND 23
           OR CAST(SUBSTRING_INDEX(TRIM(scheduled_time_raw), ':', -1) AS UNSIGNED) NOT BETWEEN 0 AND 59)
    UNION ALL
    SELECT 'estimated', TRIM(estimated_time_raw)
    FROM raw_departure_flight
    WHERE estimated_time_raw IS NOT NULL AND TRIM(estimated_time_raw) NOT IN ('', ':')
      AND (TRIM(estimated_time_raw) NOT REGEXP '^[0-9]{1,2}:[0-9]{2}$'
           OR CAST(SUBSTRING_INDEX(TRIM(estimated_time_raw), ':', 1) AS UNSIGNED) NOT BETWEEN 0 AND 23
           OR CAST(SUBSTRING_INDEX(TRIM(estimated_time_raw), ':', -1) AS UNSIGNED) NOT BETWEEN 0 AND 59)
    UNION ALL
    SELECT 'actual', TRIM(actual_departure_time_raw)
    FROM raw_departure_flight
    WHERE actual_departure_time_raw IS NOT NULL AND TRIM(actual_departure_time_raw) NOT IN ('', ':')
      AND (TRIM(actual_departure_time_raw) NOT REGEXP '^[0-9]{1,2}:[0-9]{2}$'
           OR CAST(SUBSTRING_INDEX(TRIM(actual_departure_time_raw), ':', 1) AS UNSIGNED) NOT BETWEEN 0 AND 23
           OR CAST(SUBSTRING_INDEX(TRIM(actual_departure_time_raw), ':', -1) AS UNSIGNED) NOT BETWEEN 0 AND 59)
), digit_profile AS (
    SELECT field_name, time_value,
           REPLACE(time_value, ':', '') AS digit_string,
           CHAR_LENGTH(REPLACE(time_value, ':', '')) AS digit_length
    FROM invalid_values
)
SELECT field_name, digit_length,
       SUM(digit_string REGEXP '^[0-9]+$') AS numeric_only_rows,
       SUM(digit_length = 3
           AND digit_string REGEXP '^[0-9]{3}$'
           AND CAST(SUBSTRING(digit_string, 2, 2) AS UNSIGNED) BETWEEN 0 AND 59)
           AS recoverable_as_h_mm_candidates,
       COUNT(*) AS rows_count,
       COUNT(DISTINCT time_value) AS distinct_value_count,
       SUBSTRING_INDEX(
           GROUP_CONCAT(DISTINCT time_value ORDER BY time_value SEPARATOR ', '),
           ', ', 10
       ) AS examples
FROM digit_profile
GROUP BY field_name, digit_length
ORDER BY field_name, digit_length;

-- name: invalid_time_samples
SELECT airport_name_raw, scheduled_time_raw, estimated_time_raw, actual_departure_time_raw,
       status_raw, destination_raw
FROM raw_departure_flight
WHERE (scheduled_time_raw IS NOT NULL AND TRIM(scheduled_time_raw) NOT IN ('', ':')
       AND (TRIM(scheduled_time_raw) NOT REGEXP '^[0-9]{1,2}:[0-9]{2}$'
            OR CAST(SUBSTRING_INDEX(TRIM(scheduled_time_raw), ':', 1) AS UNSIGNED) NOT BETWEEN 0 AND 23
            OR CAST(SUBSTRING_INDEX(TRIM(scheduled_time_raw), ':', -1) AS UNSIGNED) NOT BETWEEN 0 AND 59))
   OR (estimated_time_raw IS NOT NULL AND TRIM(estimated_time_raw) NOT IN ('', ':')
       AND (TRIM(estimated_time_raw) NOT REGEXP '^[0-9]{1,2}:[0-9]{2}$'
            OR CAST(SUBSTRING_INDEX(TRIM(estimated_time_raw), ':', 1) AS UNSIGNED) NOT BETWEEN 0 AND 23
            OR CAST(SUBSTRING_INDEX(TRIM(estimated_time_raw), ':', -1) AS UNSIGNED) NOT BETWEEN 0 AND 59))
   OR (actual_departure_time_raw IS NOT NULL AND TRIM(actual_departure_time_raw) NOT IN ('', ':')
       AND (TRIM(actual_departure_time_raw) NOT REGEXP '^[0-9]{1,2}:[0-9]{2}$'
            OR CAST(SUBSTRING_INDEX(TRIM(actual_departure_time_raw), ':', 1) AS UNSIGNED) NOT BETWEEN 0 AND 23
            OR CAST(SUBSTRING_INDEX(TRIM(actual_departure_time_raw), ':', -1) AS UNSIGNED) NOT BETWEEN 0 AND 59))
LIMIT 30;
