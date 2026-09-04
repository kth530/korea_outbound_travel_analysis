-- name: create_v_business_flight_base
-- 03에서 선택한 국제선 여객편·지연·자정 보정·회항 규칙을 04 공통 범위로 고정한다.
CREATE OR REPLACE VIEW v_business_flight_base AS
SELECT f.airport_name_raw,
       f.flight_date,
       f.operating_month,
       f.airline_name_raw,
       f.airline_std,
       f.flight_number_raw,
       f.flight_number_std,
       f.destination_raw,
       f.destination_canonical_std,
       f.service_type_raw,
       f.status_raw,
       f.scheduled_time_raw,
       f.estimated_time_raw,
       f.actual_departure_time_raw,
       f.delay_reason_raw,
       f.is_passenger,
       f.is_international,
       f.is_cancelled,
       f.is_diverted,
       f.is_status_unknown,
       f.is_time_calculable,
       f.raw_gap_minutes,
       f.is_denominator AS is_status_operated,
       f.status_raw = '지연' AS is_status_delayed,
       f.is_denominator AND f.is_time_calculable AS is_time_delay_denominator,
       CASE
           WHEN f.is_time_calculable AND f.raw_gap_minutes <= -720
               THEN f.raw_gap_minutes + 1440
           WHEN f.is_time_calculable THEN f.raw_gap_minutes
       END AS adjusted_gap_minutes,
       f.is_time_calculable AND f.raw_gap_minutes <= -720 AS is_midnight_adjusted,
       f.is_denominator
           AND f.is_time_calculable
           AND (CASE WHEN f.raw_gap_minutes <= -720
                     THEN f.raw_gap_minutes + 1440
                     ELSE f.raw_gap_minutes END) >= 15 AS is_time_delayed_15,
       f.delay_reason_std,
       f.is_reason_operational_outcome,
       CASE
           WHEN f.is_reason_operational_outcome THEN NULL
           WHEN f.delay_reason_std IS NULL OR TRIM(f.delay_reason_std) = '' THEN '미입력'
           ELSE f.delay_reason_std
       END AS delay_reason_business_std
FROM v_flight_analysis AS f
WHERE f.is_passenger = TRUE
  AND f.is_international = TRUE;

-- name: create_v_metric_demand_country_monthly
-- 국가별 국제선 여객 수요·월 비중·전년 동월 변화를 제공한다.
CREATE OR REPLACE VIEW v_metric_demand_country_monthly AS
WITH monthly AS (
    SELECT period_ym, region_raw, country_raw,
           SUM(passengers) AS passengers
    FROM v_country_monthly
    WHERE period_ym IS NOT NULL
    GROUP BY period_ym, region_raw, country_raw
), with_share AS (
    SELECT monthly.*,
           ROUND(passengers / NULLIF(SUM(passengers) OVER (PARTITION BY period_ym), 0), 4)
               AS passenger_share
    FROM monthly
)
SELECT current_month.period_ym, current_month.region_raw, current_month.country_raw,
       current_month.passengers, current_month.passenger_share,
       previous_month.passengers AS previous_year_passengers,
       ROUND(
           (current_month.passengers - previous_month.passengers)
               / NULLIF(previous_month.passengers, 0),
           4
       ) AS passenger_yoy_rate
FROM with_share AS current_month
LEFT JOIN with_share AS previous_month
  ON previous_month.region_raw <=> current_month.region_raw
 AND previous_month.country_raw <=> current_month.country_raw
 AND previous_month.period_ym = DATE_FORMAT(
     DATE_SUB(STR_TO_DATE(CONCAT(current_month.period_ym, '01'), '%Y%m%d'), INTERVAL 1 YEAR),
     '%Y%m'
 );

-- name: create_v_metric_demand_destination_monthly
-- 목적지별 국제선 여객·운항·월 비중·전년 동월 변화를 제공한다.
CREATE OR REPLACE VIEW v_metric_demand_destination_monthly AS
WITH monthly AS (
    SELECT period_ym,
           destination_airport_std AS destination_canonical_std,
           SUM(passengers) AS passengers,
           SUM(operations) AS operations
    FROM v_route_monthly
    WHERE is_international = TRUE
      AND period_ym IS NOT NULL
    GROUP BY period_ym, destination_airport_std
), with_share AS (
    SELECT monthly.*,
           ROUND(passengers / NULLIF(SUM(passengers) OVER (PARTITION BY period_ym), 0), 4)
               AS passenger_share
    FROM monthly
)
SELECT current_month.period_ym,
       current_month.destination_canonical_std,
       current_month.passengers, current_month.operations, current_month.passenger_share,
       ROUND(current_month.passengers / NULLIF(current_month.operations, 0), 2)
           AS passengers_per_operation,
       previous_month.passengers AS previous_year_passengers,
       ROUND(
           (current_month.passengers - previous_month.passengers)
               / NULLIF(previous_month.passengers, 0),
           4
       ) AS passenger_yoy_rate,
       previous_month.operations AS previous_year_operations,
       ROUND(
           (current_month.operations - previous_month.operations)
               / NULLIF(previous_month.operations, 0),
           4
       ) AS operation_yoy_rate
FROM with_share AS current_month
LEFT JOIN with_share AS previous_month
  ON previous_month.destination_canonical_std <=> current_month.destination_canonical_std
 AND previous_month.period_ym = DATE_FORMAT(
     DATE_SUB(STR_TO_DATE(CONCAT(current_month.period_ym, '01'), '%Y%m%d'), INTERVAL 1 YEAR),
     '%Y%m'
 );

-- name: create_v_metric_demand_route_monthly
-- 출발공항·목적지 노선별 국제선 여객·운항·월 비중·전년 동월 변화를 제공한다.
CREATE OR REPLACE VIEW v_metric_demand_route_monthly AS
WITH monthly AS (
    SELECT period_ym,
           origin_airport_std,
           destination_airport_std AS destination_canonical_std,
           SUM(passengers) AS passengers,
           SUM(operations) AS operations
    FROM v_route_monthly
    WHERE is_international = TRUE
      AND period_ym IS NOT NULL
    GROUP BY period_ym, origin_airport_std, destination_airport_std
), with_share AS (
    SELECT monthly.*,
           ROUND(passengers / NULLIF(SUM(passengers) OVER (PARTITION BY period_ym), 0), 4)
               AS passenger_share
    FROM monthly
)
SELECT current_month.period_ym,
       current_month.origin_airport_std,
       current_month.destination_canonical_std,
       current_month.passengers, current_month.operations, current_month.passenger_share,
       ROUND(current_month.passengers / NULLIF(current_month.operations, 0), 2)
           AS passengers_per_operation,
       previous_month.passengers AS previous_year_passengers,
       ROUND(
           (current_month.passengers - previous_month.passengers)
               / NULLIF(previous_month.passengers, 0),
           4
       ) AS passenger_yoy_rate,
       previous_month.operations AS previous_year_operations,
       ROUND(
           (current_month.operations - previous_month.operations)
               / NULLIF(previous_month.operations, 0),
           4
       ) AS operation_yoy_rate
FROM with_share AS current_month
LEFT JOIN with_share AS previous_month
  ON previous_month.origin_airport_std <=> current_month.origin_airport_std
 AND previous_month.destination_canonical_std <=> current_month.destination_canonical_std
 AND previous_month.period_ym = DATE_FORMAT(
     DATE_SUB(STR_TO_DATE(CONCAT(current_month.period_ym, '01'), '%Y%m%d'), INTERVAL 1 YEAR),
     '%Y%m'
 );

-- name: create_v_metric_operation_monthly
-- 인천·김포 국제선 여객편의 월별 운영상 지연·15분 지연·취소·회항·지연시간을 제공한다.
CREATE OR REPLACE VIEW v_metric_operation_monthly AS
WITH aggregated AS (
    SELECT operating_month,
           COUNT(*) AS scheduled_flight_rows,
           SUM(is_status_operated) AS status_operated_rows,
           SUM(is_status_delayed) AS status_delayed_rows,
           SUM(is_time_delay_denominator) AS time_delay_denominator_rows,
           SUM(is_time_delayed_15) AS time_delayed_15_rows,
           SUM(is_cancelled) AS cancelled_rows,
           SUM(is_diverted) AS diverted_rows,
           ROUND(AVG(CASE WHEN is_time_delay_denominator THEN adjusted_gap_minutes END), 2)
               AS avg_departure_gap_minutes,
           ROUND(AVG(CASE WHEN is_time_delayed_15 THEN adjusted_gap_minutes END), 2)
               AS avg_delay_minutes
    FROM v_business_flight_base
    WHERE operating_month IS NOT NULL
    GROUP BY operating_month
), ranked_delays AS (
    SELECT operating_month, adjusted_gap_minutes,
           ROW_NUMBER() OVER (PARTITION BY operating_month ORDER BY adjusted_gap_minutes) AS delay_rank,
           COUNT(*) OVER (PARTITION BY operating_month) AS delay_count
    FROM v_business_flight_base
    WHERE operating_month IS NOT NULL
      AND is_time_delayed_15
), medians AS (
    SELECT operating_month,
           ROUND(AVG(adjusted_gap_minutes), 2) AS median_delay_minutes
    FROM ranked_delays
    WHERE delay_rank IN (
        FLOOR((delay_count + 1) / 2),
        FLOOR((delay_count + 2) / 2)
    )
    GROUP BY operating_month
)
SELECT a.*,
       ROUND(status_delayed_rows / NULLIF(status_operated_rows, 0), 4) AS status_delay_rate,
       ROUND(time_delayed_15_rows / NULLIF(time_delay_denominator_rows, 0), 4)
           AS time_delay_15_rate,
       ROUND(cancelled_rows / NULLIF(scheduled_flight_rows, 0), 4) AS cancellation_rate,
       ROUND(diverted_rows / NULLIF(scheduled_flight_rows, 0), 4) AS diversion_rate,
       m.median_delay_minutes
FROM aggregated AS a
LEFT JOIN medians AS m USING (operating_month);

-- name: create_v_metric_operation_airport_monthly
-- 공항별 월간 운항 안정성 지표를 제공한다.
CREATE OR REPLACE VIEW v_metric_operation_airport_monthly AS
WITH aggregated AS (
    SELECT operating_month, airport_name_raw,
           COUNT(*) AS scheduled_flight_rows,
           SUM(is_status_operated) AS status_operated_rows,
           SUM(is_status_delayed) AS status_delayed_rows,
           SUM(is_time_delay_denominator) AS time_delay_denominator_rows,
           SUM(is_time_delayed_15) AS time_delayed_15_rows,
           SUM(is_cancelled) AS cancelled_rows,
           SUM(is_diverted) AS diverted_rows,
           ROUND(AVG(CASE WHEN is_time_delay_denominator THEN adjusted_gap_minutes END), 2)
               AS avg_departure_gap_minutes,
           ROUND(AVG(CASE WHEN is_time_delayed_15 THEN adjusted_gap_minutes END), 2)
               AS avg_delay_minutes
    FROM v_business_flight_base
    WHERE operating_month IS NOT NULL
    GROUP BY operating_month, airport_name_raw
), ranked_delays AS (
    SELECT operating_month, airport_name_raw, adjusted_gap_minutes,
           ROW_NUMBER() OVER (
               PARTITION BY operating_month, airport_name_raw ORDER BY adjusted_gap_minutes
           ) AS delay_rank,
           COUNT(*) OVER (PARTITION BY operating_month, airport_name_raw) AS delay_count
    FROM v_business_flight_base
    WHERE operating_month IS NOT NULL
      AND is_time_delayed_15
), medians AS (
    SELECT operating_month, airport_name_raw,
           ROUND(AVG(adjusted_gap_minutes), 2) AS median_delay_minutes
    FROM ranked_delays
    WHERE delay_rank IN (
        FLOOR((delay_count + 1) / 2),
        FLOOR((delay_count + 2) / 2)
    )
    GROUP BY operating_month, airport_name_raw
)
SELECT a.*,
       ROUND(status_delayed_rows / NULLIF(status_operated_rows, 0), 4) AS status_delay_rate,
       ROUND(time_delayed_15_rows / NULLIF(time_delay_denominator_rows, 0), 4)
           AS time_delay_15_rate,
       ROUND(cancelled_rows / NULLIF(scheduled_flight_rows, 0), 4) AS cancellation_rate,
       ROUND(diverted_rows / NULLIF(scheduled_flight_rows, 0), 4) AS diversion_rate,
       m.median_delay_minutes
FROM aggregated AS a
LEFT JOIN medians AS m USING (operating_month, airport_name_raw);

-- name: create_v_metric_operation_airline_monthly
-- 항공사별 월간 운항 안정성 지표를 제공한다.
CREATE OR REPLACE VIEW v_metric_operation_airline_monthly AS
SELECT operating_month,
       COALESCE(airline_std, '(NULL)') AS airline_std,
       COUNT(*) AS scheduled_flight_rows,
       SUM(is_status_operated) AS status_operated_rows,
       SUM(is_status_delayed) AS status_delayed_rows,
       ROUND(SUM(is_status_delayed) / NULLIF(SUM(is_status_operated), 0), 4)
           AS status_delay_rate,
       SUM(is_time_delay_denominator) AS time_delay_denominator_rows,
       SUM(is_time_delayed_15) AS time_delayed_15_rows,
       ROUND(SUM(is_time_delayed_15) / NULLIF(SUM(is_time_delay_denominator), 0), 4)
           AS time_delay_15_rate,
       SUM(is_cancelled) AS cancelled_rows,
       ROUND(SUM(is_cancelled) / NULLIF(COUNT(*), 0), 4) AS cancellation_rate,
       SUM(is_diverted) AS diverted_rows,
       ROUND(SUM(is_diverted) / NULLIF(COUNT(*), 0), 4) AS diversion_rate,
       ROUND(AVG(CASE WHEN is_time_delayed_15 THEN adjusted_gap_minutes END), 2)
           AS avg_delay_minutes
FROM v_business_flight_base
WHERE operating_month IS NOT NULL
GROUP BY operating_month, COALESCE(airline_std, '(NULL)');

-- name: create_v_metric_operation_destination_monthly
-- 목적지별 월간 운항 안정성 지표를 제공한다.
CREATE OR REPLACE VIEW v_metric_operation_destination_monthly AS
SELECT operating_month, destination_canonical_std,
       COUNT(*) AS scheduled_flight_rows,
       SUM(is_status_operated) AS status_operated_rows,
       SUM(is_status_delayed) AS status_delayed_rows,
       ROUND(SUM(is_status_delayed) / NULLIF(SUM(is_status_operated), 0), 4)
           AS status_delay_rate,
       SUM(is_time_delay_denominator) AS time_delay_denominator_rows,
       SUM(is_time_delayed_15) AS time_delayed_15_rows,
       ROUND(SUM(is_time_delayed_15) / NULLIF(SUM(is_time_delay_denominator), 0), 4)
           AS time_delay_15_rate,
       SUM(is_cancelled) AS cancelled_rows,
       ROUND(SUM(is_cancelled) / NULLIF(COUNT(*), 0), 4) AS cancellation_rate,
       SUM(is_diverted) AS diverted_rows,
       ROUND(SUM(is_diverted) / NULLIF(COUNT(*), 0), 4) AS diversion_rate,
       ROUND(AVG(CASE WHEN is_time_delayed_15 THEN adjusted_gap_minutes END), 2)
           AS avg_delay_minutes
FROM v_business_flight_base
WHERE operating_month IS NOT NULL
GROUP BY operating_month, destination_canonical_std;

-- name: create_v_metric_delay_reason_monthly
-- 월·공항·항공사·목적지별 상태 지연 사유 건수를 한 구조로 제공한다.
CREATE OR REPLACE VIEW v_metric_delay_reason_monthly AS
SELECT operating_month,
       airport_name_raw,
       COALESCE(airline_std, '(NULL)') AS airline_std,
       COALESCE(destination_canonical_std, '(NULL)') AS destination_canonical_std,
       delay_reason_business_std AS delay_reason_category,
       COUNT(*) AS delayed_flight_rows
FROM v_business_flight_base
WHERE operating_month IS NOT NULL
  AND is_status_delayed
  AND NOT is_reason_operational_outcome
GROUP BY operating_month,
         airport_name_raw,
         COALESCE(airline_std, '(NULL)'),
         COALESCE(destination_canonical_std, '(NULL)'),
         delay_reason_business_std;

-- name: business_rule_profile
-- 04 공통 범위와 선택한 보정·지연·운항결과 규칙의 적용 건수를 확인한다.
SELECT airport_name_raw,
       COUNT(*) AS scheduled_flight_rows,
       SUM(is_status_operated) AS status_operated_rows,
       SUM(is_status_delayed) AS status_delayed_rows,
       ROUND(SUM(is_status_delayed) / NULLIF(SUM(is_status_operated), 0), 4)
           AS status_delay_rate,
       SUM(is_time_delay_denominator) AS time_delay_denominator_rows,
       SUM(is_time_delayed_15) AS time_delayed_15_rows,
       ROUND(SUM(is_time_delayed_15) / NULLIF(SUM(is_time_delay_denominator), 0), 4)
           AS time_delay_15_rate,
       SUM(is_midnight_adjusted) AS midnight_adjusted_rows,
       SUM(is_cancelled) AS cancelled_rows,
       SUM(is_diverted) AS diverted_rows,
       SUM(is_status_unknown) AS status_unknown_rows
FROM v_business_flight_base
GROUP BY airport_name_raw
ORDER BY airport_name_raw;

-- name: business_view_coverage
-- 유지하는 9개 핵심 뷰의 기간과 행 수를 확인한다.
SELECT 'v_business_flight_base' AS view_name,
       MIN(operating_month) AS first_period_ym,
       MAX(operating_month) AS last_period_ym,
       COUNT(*) AS rows_count
FROM v_business_flight_base
UNION ALL
SELECT 'v_metric_demand_country_monthly', MIN(period_ym), MAX(period_ym), COUNT(*)
FROM v_metric_demand_country_monthly
UNION ALL
SELECT 'v_metric_demand_destination_monthly', MIN(period_ym), MAX(period_ym), COUNT(*)
FROM v_metric_demand_destination_monthly
UNION ALL
SELECT 'v_metric_demand_route_monthly', MIN(period_ym), MAX(period_ym), COUNT(*)
FROM v_metric_demand_route_monthly
UNION ALL
SELECT 'v_metric_operation_monthly', MIN(operating_month), MAX(operating_month), COUNT(*)
FROM v_metric_operation_monthly
UNION ALL
SELECT 'v_metric_operation_airport_monthly', MIN(operating_month), MAX(operating_month), COUNT(*)
FROM v_metric_operation_airport_monthly
UNION ALL
SELECT 'v_metric_operation_airline_monthly', MIN(operating_month), MAX(operating_month), COUNT(*)
FROM v_metric_operation_airline_monthly
UNION ALL
SELECT 'v_metric_operation_destination_monthly', MIN(operating_month), MAX(operating_month), COUNT(*)
FROM v_metric_operation_destination_monthly
UNION ALL
SELECT 'v_metric_delay_reason_monthly', MIN(operating_month), MAX(operating_month), COUNT(*)
FROM v_metric_delay_reason_monthly
ORDER BY view_name;

-- name: demand_metric_monthly_total_check
-- 수요 차원별 월 합계를 원본 집계 뷰의 국제선 기준과 비교한다.
WITH expected AS (
    SELECT period_ym,
           SUM(passengers) AS passengers,
           SUM(operations) AS operations
    FROM v_route_monthly
    WHERE is_international = TRUE
      AND period_ym IS NOT NULL
    GROUP BY period_ym
), dimension_totals AS (
    SELECT 'airport' AS metric_name, period_ym,
           SUM(passengers) AS passengers, NULL AS operations
    FROM v_airport_monthly
    WHERE period_ym IS NOT NULL
    GROUP BY period_ym
    UNION ALL
    SELECT 'country', period_ym, SUM(passengers), NULL
    FROM v_metric_demand_country_monthly
    GROUP BY period_ym
    UNION ALL
    SELECT 'airline', period_ym, SUM(passengers), SUM(operations)
    FROM v_airline_monthly
    WHERE period_ym IS NOT NULL
    GROUP BY period_ym
    UNION ALL
    SELECT 'destination', period_ym, SUM(passengers), SUM(operations)
    FROM v_metric_demand_destination_monthly
    GROUP BY period_ym
    UNION ALL
    SELECT 'route', period_ym, SUM(passengers), SUM(operations)
    FROM v_metric_demand_route_monthly
    GROUP BY period_ym
)
SELECT metric_name,
       COUNT(*) AS checked_months,
       SUM(ABS(d.passengers - e.passengers)) AS passenger_absolute_difference,
       MAX(ABS(d.passengers - e.passengers)) AS passenger_max_month_difference,
       SUM(CASE WHEN d.operations IS NULL THEN NULL ELSE ABS(d.operations - e.operations) END)
           AS operation_absolute_difference,
       MAX(CASE WHEN d.operations IS NULL THEN NULL ELSE ABS(d.operations - e.operations) END)
           AS operation_max_month_difference,
       SUM(CASE WHEN d.operations IS NOT NULL AND d.operations <> e.operations THEN 1 ELSE 0 END)
           AS operation_difference_month_count,
       GROUP_CONCAT(
           CASE WHEN d.operations IS NOT NULL AND d.operations <> e.operations THEN d.period_ym END
           ORDER BY d.period_ym SEPARATOR ', '
       ) AS operation_difference_periods
FROM dimension_totals AS d
JOIN expected AS e USING (period_ym)
GROUP BY metric_name
ORDER BY FIELD(metric_name, 'airport', 'country', 'airline', 'destination', 'route');

-- name: operation_metric_total_check
-- 공항 월간 지표를 합한 건수가 04 공통 여객편 범위와 일치하는지 확인한다.
WITH base AS (
    SELECT airport_name_raw,
           COUNT(*) AS scheduled_flight_rows,
           SUM(is_status_operated) AS status_operated_rows,
           SUM(is_status_delayed) AS status_delayed_rows,
           SUM(is_time_delay_denominator) AS time_delay_denominator_rows,
           SUM(is_time_delayed_15) AS time_delayed_15_rows,
           SUM(is_cancelled) AS cancelled_rows,
           SUM(is_diverted) AS diverted_rows
    FROM v_business_flight_base
    WHERE operating_month IS NOT NULL
    GROUP BY airport_name_raw
), metric AS (
    SELECT airport_name_raw,
           SUM(scheduled_flight_rows) AS scheduled_flight_rows,
           SUM(status_operated_rows) AS status_operated_rows,
           SUM(status_delayed_rows) AS status_delayed_rows,
           SUM(time_delay_denominator_rows) AS time_delay_denominator_rows,
           SUM(time_delayed_15_rows) AS time_delayed_15_rows,
           SUM(cancelled_rows) AS cancelled_rows,
           SUM(diverted_rows) AS diverted_rows
    FROM v_metric_operation_airport_monthly
    GROUP BY airport_name_raw
)
SELECT b.airport_name_raw,
       m.scheduled_flight_rows - b.scheduled_flight_rows AS scheduled_row_difference,
       m.status_operated_rows - b.status_operated_rows AS status_operated_difference,
       m.status_delayed_rows - b.status_delayed_rows AS status_delayed_difference,
       m.time_delay_denominator_rows - b.time_delay_denominator_rows
           AS time_delay_denominator_difference,
       m.time_delayed_15_rows - b.time_delayed_15_rows AS time_delayed_15_difference,
       m.cancelled_rows - b.cancelled_rows AS cancelled_difference,
       m.diverted_rows - b.diverted_rows AS diverted_difference
FROM base AS b
JOIN metric AS m USING (airport_name_raw)
ORDER BY b.airport_name_raw;

-- name: monthly_demand_metrics
WITH monthly AS (
    SELECT period_ym,
           SUM(passengers) AS passengers,
           SUM(operations) AS operations
    FROM v_route_monthly
    WHERE is_international = TRUE
      AND period_ym IS NOT NULL
    GROUP BY period_ym
), compared AS (
    SELECT current_month.*,
           previous_month.passengers AS previous_year_passengers,
           previous_month.operations AS previous_year_operations
    FROM monthly AS current_month
    LEFT JOIN monthly AS previous_month
      ON previous_month.period_ym = DATE_FORMAT(
          DATE_SUB(STR_TO_DATE(CONCAT(current_month.period_ym, '01'), '%Y%m%d'), INTERVAL 1 YEAR),
          '%Y%m'
      )
), monthly_demand AS (
SELECT period_ym, passengers, operations,
       ROUND(passengers / NULLIF(operations, 0), 2) AS passengers_per_operation,
       previous_year_passengers,
       ROUND((passengers - previous_year_passengers) / NULLIF(previous_year_passengers, 0), 4)
           AS passenger_yoy_rate,
       previous_year_operations,
       ROUND((operations - previous_year_operations) / NULLIF(previous_year_operations, 0), 4)
           AS operation_yoy_rate
FROM compared
)
SELECT *
FROM monthly_demand
ORDER BY period_ym;

-- name: yearly_airport_demand_metrics
-- 3개년 누적 여객 순위로 공항을 고정하고 연도별 수요를 비교한다.
WITH standardized AS (
    SELECT period_ym,
           NULLIF(
               REGEXP_REPLACE(
                   REGEXP_REPLACE(TRIM(airport_name_raw), '\\([^)]*\\)', ''),
                   '[[:space:]/_-]',
                   ''
               ),
               ''
           ) AS airport_std,
           passengers
    FROM v_airport_monthly
    WHERE period_ym IS NOT NULL
), yearly AS (
    SELECT LEFT(period_ym, 4) AS operating_year, airport_std,
           SUM(passengers) AS passengers
    FROM standardized
    GROUP BY LEFT(period_ym, 4), airport_std
), totals AS (
    SELECT airport_std,
           SUM(passengers) AS total_period_passengers
    FROM yearly
    GROUP BY airport_std
), ranked AS (
    SELECT totals.*,
           ROW_NUMBER() OVER (
               ORDER BY total_period_passengers DESC, airport_std
           ) AS total_rank
    FROM totals
), with_share AS (
    SELECT yearly.*,
           ROUND(passengers / NULLIF(SUM(passengers) OVER (PARTITION BY operating_year), 0), 4)
               AS passenger_share
    FROM yearly
), airport_demand AS (
SELECT current_year.operating_year, ranked.total_rank,
       ranked.total_period_passengers,
       current_year.airport_std,
       current_year.passengers, current_year.passenger_share,
       previous_year.passengers AS previous_annual_passengers,
       ROUND(
           (current_year.passengers - previous_year.passengers)
               / NULLIF(previous_year.passengers, 0),
           4
       ) AS annual_passenger_yoy_rate
FROM with_share AS current_year
JOIN ranked
  ON ranked.airport_std <=> current_year.airport_std
LEFT JOIN with_share AS previous_year
  ON previous_year.airport_std <=> current_year.airport_std
 AND CAST(previous_year.operating_year AS UNSIGNED)
     = CAST(current_year.operating_year AS UNSIGNED) - 1
)
SELECT *
FROM airport_demand
ORDER BY total_rank, operating_year;

-- name: yearly_country_demand_metrics
-- 3개년 누적 여객 상위 10개 국가의 연도별 수요를 비교한다.
WITH yearly AS (
    SELECT LEFT(period_ym, 4) AS operating_year,
           region_raw, country_raw,
           SUM(passengers) AS passengers
    FROM v_metric_demand_country_monthly
    GROUP BY LEFT(period_ym, 4), region_raw, country_raw
), totals AS (
    SELECT region_raw, country_raw,
           SUM(passengers) AS total_period_passengers
    FROM yearly
    GROUP BY region_raw, country_raw
), ranked AS (
    SELECT totals.*,
           ROW_NUMBER() OVER (
               ORDER BY total_period_passengers DESC, region_raw, country_raw
           ) AS total_rank
    FROM totals
), with_share AS (
    SELECT yearly.*,
           ROUND(passengers / NULLIF(SUM(passengers) OVER (PARTITION BY operating_year), 0), 4)
               AS passenger_share
    FROM yearly
)
SELECT current_year.operating_year, ranked.total_rank,
       ranked.total_period_passengers,
       current_year.region_raw, current_year.country_raw,
       current_year.passengers, current_year.passenger_share,
       previous_year.passengers AS previous_annual_passengers,
       ROUND(
           (current_year.passengers - previous_year.passengers)
               / NULLIF(previous_year.passengers, 0),
           4
       ) AS annual_passenger_yoy_rate
FROM with_share AS current_year
JOIN ranked
  ON ranked.region_raw <=> current_year.region_raw
 AND ranked.country_raw <=> current_year.country_raw
LEFT JOIN with_share AS previous_year
  ON previous_year.region_raw <=> current_year.region_raw
 AND previous_year.country_raw <=> current_year.country_raw
 AND CAST(previous_year.operating_year AS UNSIGNED)
     = CAST(current_year.operating_year AS UNSIGNED) - 1
WHERE ranked.total_rank <= 10
ORDER BY ranked.total_rank, current_year.operating_year;

-- name: yearly_destination_demand_metrics
-- 3개년 누적 여객 상위 10개 목적지의 연도별 수요를 비교한다.
WITH yearly AS (
    SELECT LEFT(period_ym, 4) AS operating_year,
           destination_canonical_std,
           SUM(passengers) AS passengers,
           SUM(operations) AS operations
    FROM v_metric_demand_destination_monthly
    GROUP BY LEFT(period_ym, 4), destination_canonical_std
), totals AS (
    SELECT destination_canonical_std,
           SUM(passengers) AS total_period_passengers
    FROM yearly
    GROUP BY destination_canonical_std
), ranked AS (
    SELECT totals.*,
           ROW_NUMBER() OVER (
               ORDER BY total_period_passengers DESC, destination_canonical_std
           ) AS total_rank
    FROM totals
), with_share AS (
    SELECT yearly.*,
           ROUND(passengers / NULLIF(SUM(passengers) OVER (PARTITION BY operating_year), 0), 4)
               AS passenger_share
    FROM yearly
)
SELECT current_year.operating_year, ranked.total_rank,
       ranked.total_period_passengers,
       current_year.destination_canonical_std,
       current_year.passengers, current_year.operations,
       current_year.passenger_share,
       ROUND(current_year.passengers / NULLIF(current_year.operations, 0), 2)
           AS passengers_per_operation,
       previous_year.passengers AS previous_annual_passengers,
       ROUND(
           (current_year.passengers - previous_year.passengers)
               / NULLIF(previous_year.passengers, 0),
           4
       ) AS annual_passenger_yoy_rate,
       previous_year.operations AS previous_annual_operations,
       ROUND(
           (current_year.operations - previous_year.operations)
               / NULLIF(previous_year.operations, 0),
           4
       ) AS annual_operation_yoy_rate
FROM with_share AS current_year
JOIN ranked
  ON ranked.destination_canonical_std <=> current_year.destination_canonical_std
LEFT JOIN with_share AS previous_year
  ON previous_year.destination_canonical_std <=> current_year.destination_canonical_std
 AND CAST(previous_year.operating_year AS UNSIGNED)
     = CAST(current_year.operating_year AS UNSIGNED) - 1
WHERE ranked.total_rank <= 10
ORDER BY ranked.total_rank, current_year.operating_year;

-- name: yearly_route_demand_metrics
-- 3개년 누적 여객 상위 10개 노선의 연도별 수요를 비교한다.
WITH yearly AS (
    SELECT LEFT(period_ym, 4) AS operating_year,
           origin_airport_std, destination_canonical_std,
           SUM(passengers) AS passengers,
           SUM(operations) AS operations
    FROM v_metric_demand_route_monthly
    GROUP BY LEFT(period_ym, 4), origin_airport_std, destination_canonical_std
), totals AS (
    SELECT origin_airport_std, destination_canonical_std,
           SUM(passengers) AS total_period_passengers
    FROM yearly
    GROUP BY origin_airport_std, destination_canonical_std
), ranked AS (
    SELECT totals.*,
           ROW_NUMBER() OVER (
               ORDER BY total_period_passengers DESC,
                        origin_airport_std, destination_canonical_std
           ) AS total_rank
    FROM totals
), with_share AS (
    SELECT yearly.*,
           ROUND(passengers / NULLIF(SUM(passengers) OVER (PARTITION BY operating_year), 0), 4)
               AS passenger_share
    FROM yearly
)
SELECT current_year.operating_year, ranked.total_rank,
       ranked.total_period_passengers,
       current_year.origin_airport_std,
       current_year.destination_canonical_std,
       current_year.passengers, current_year.operations,
       current_year.passenger_share,
       ROUND(current_year.passengers / NULLIF(current_year.operations, 0), 2)
           AS passengers_per_operation,
       previous_year.passengers AS previous_annual_passengers,
       ROUND(
           (current_year.passengers - previous_year.passengers)
               / NULLIF(previous_year.passengers, 0),
           4
       ) AS annual_passenger_yoy_rate,
       previous_year.operations AS previous_annual_operations,
       ROUND(
           (current_year.operations - previous_year.operations)
               / NULLIF(previous_year.operations, 0),
           4
       ) AS annual_operation_yoy_rate
FROM with_share AS current_year
JOIN ranked
  ON ranked.origin_airport_std <=> current_year.origin_airport_std
 AND ranked.destination_canonical_std <=> current_year.destination_canonical_std
LEFT JOIN with_share AS previous_year
  ON previous_year.origin_airport_std <=> current_year.origin_airport_std
 AND previous_year.destination_canonical_std <=> current_year.destination_canonical_std
 AND CAST(previous_year.operating_year AS UNSIGNED)
     = CAST(current_year.operating_year AS UNSIGNED) - 1
WHERE ranked.total_rank <= 10
ORDER BY ranked.total_rank, current_year.operating_year;

-- name: seasonal_destination_metrics
WITH indexed AS (
    SELECT period_ym, destination_canonical_std,
           passengers, operations,
           passengers / NULLIF(
               AVG(passengers) OVER (
                   PARTITION BY destination_canonical_std, LEFT(period_ym, 4)
               ),
               0
           ) AS passenger_seasonal_index
    FROM v_metric_demand_destination_monthly
), seasonal_destination AS (
SELECT RIGHT(period_ym, 2) AS calendar_month,
       destination_canonical_std,
       COUNT(*) AS observed_years,
       ROUND(AVG(passengers), 0) AS avg_passengers,
       MIN(passengers) AS min_passengers,
       MAX(passengers) AS max_passengers,
       ROUND(AVG(passenger_seasonal_index), 4) AS avg_passenger_seasonal_index,
       ROUND(AVG(operations), 0) AS avg_operations
FROM indexed
GROUP BY RIGHT(period_ym, 2), destination_canonical_std
), ranked AS (
    SELECT seasonal_destination.*,
           ROW_NUMBER() OVER (
               PARTITION BY calendar_month
               ORDER BY avg_passengers DESC, destination_canonical_std
           ) AS demand_rank
    FROM seasonal_destination
    WHERE observed_years = 3
)
SELECT *
FROM ranked
WHERE demand_rank <= 5
ORDER BY calendar_month, demand_rank;

-- name: growth_destination_metrics
WITH yearly AS (
    SELECT LEFT(period_ym, 4) AS operating_year,
           destination_canonical_std,
           COUNT(*) AS observed_months,
           SUM(passengers) AS passengers,
           SUM(operations) AS operations
    FROM v_metric_demand_destination_monthly
    GROUP BY LEFT(period_ym, 4), destination_canonical_std
), bounds AS (
    SELECT MAX(operating_year) AS latest_year
    FROM yearly
), pivoted AS (
    SELECT y.destination_canonical_std,
           b.latest_year,
           CAST(b.latest_year AS UNSIGNED) - 1 AS previous_year,
           MAX(CASE WHEN y.operating_year = b.latest_year THEN y.observed_months END)
               AS latest_year_observed_months,
           MAX(CASE WHEN CAST(y.operating_year AS UNSIGNED) = CAST(b.latest_year AS UNSIGNED) - 1
                    THEN y.observed_months END) AS previous_year_observed_months,
           MAX(CASE WHEN y.operating_year = b.latest_year THEN y.passengers END)
               AS latest_year_passengers,
           MAX(CASE WHEN CAST(y.operating_year AS UNSIGNED) = CAST(b.latest_year AS UNSIGNED) - 1
                    THEN y.passengers END) AS comparison_year_passengers,
           MAX(CASE WHEN y.operating_year = b.latest_year THEN y.operations END)
               AS latest_year_operations,
           MAX(CASE WHEN CAST(y.operating_year AS UNSIGNED) = CAST(b.latest_year AS UNSIGNED) - 1
                    THEN y.operations END) AS comparison_year_operations
    FROM yearly AS y
    CROSS JOIN bounds AS b
    GROUP BY y.destination_canonical_std, b.latest_year
), growth_destination AS (
SELECT pivoted.*,
       latest_year_passengers - comparison_year_passengers AS passenger_growth,
       ROUND(
           (latest_year_passengers - comparison_year_passengers)
               / NULLIF(comparison_year_passengers, 0),
           4
       ) AS passenger_growth_rate,
       latest_year_operations - comparison_year_operations AS operation_growth,
       ROUND(
           (latest_year_operations - comparison_year_operations)
               / NULLIF(comparison_year_operations, 0),
           4
       ) AS operation_growth_rate
FROM pivoted
)
SELECT *
FROM growth_destination
WHERE latest_year_observed_months = 12
  AND previous_year_observed_months = 12
  AND comparison_year_passengers > 0
ORDER BY passenger_growth DESC, destination_canonical_std
LIMIT 30;
-- name: monthly_operation_metrics
SELECT *
FROM v_metric_operation_monthly
ORDER BY operating_month;

-- name: airport_operation_metrics
SELECT *
FROM v_metric_operation_airport_monthly
ORDER BY operating_month, airport_name_raw;

-- name: yearly_destination_operation_metrics
-- 3개년 누적 운항 로그 상위 10개 목적지의 연도별 운항 안정성을 비교한다.
WITH yearly AS (
    SELECT LEFT(operating_month, 4) AS operating_year,
           destination_canonical_std,
           SUM(scheduled_flight_rows) AS scheduled_flight_rows,
           SUM(status_operated_rows) AS status_operated_rows,
           SUM(status_delayed_rows) AS status_delayed_rows,
           SUM(time_delay_denominator_rows) AS time_delay_denominator_rows,
           SUM(time_delayed_15_rows) AS time_delayed_15_rows,
           SUM(cancelled_rows) AS cancelled_rows,
           SUM(diverted_rows) AS diverted_rows,
           ROUND(
               SUM(avg_delay_minutes * time_delayed_15_rows)
                   / NULLIF(SUM(time_delayed_15_rows), 0),
               2
           ) AS avg_delay_minutes
    FROM v_metric_operation_destination_monthly
    GROUP BY LEFT(operating_month, 4), destination_canonical_std
), totals AS (
    SELECT destination_canonical_std,
           SUM(scheduled_flight_rows) AS total_period_scheduled_flight_rows
    FROM yearly
    GROUP BY destination_canonical_std
), ranked AS (
    SELECT totals.*,
           ROW_NUMBER() OVER (
               ORDER BY total_period_scheduled_flight_rows DESC,
                        destination_canonical_std
           ) AS total_rank
    FROM totals
)
SELECT yearly.operating_year, ranked.total_rank,
       ranked.total_period_scheduled_flight_rows,
       yearly.destination_canonical_std,
       yearly.scheduled_flight_rows,
       yearly.status_operated_rows, yearly.status_delayed_rows,
       ROUND(
           yearly.status_delayed_rows / NULLIF(yearly.status_operated_rows, 0),
           4
       ) AS status_delay_rate,
       yearly.time_delay_denominator_rows, yearly.time_delayed_15_rows,
       ROUND(
           yearly.time_delayed_15_rows
               / NULLIF(yearly.time_delay_denominator_rows, 0),
           4
       ) AS time_delay_15_rate,
       yearly.cancelled_rows,
       ROUND(
           yearly.cancelled_rows / NULLIF(yearly.scheduled_flight_rows, 0),
           4
       ) AS cancellation_rate,
       yearly.diverted_rows,
       ROUND(
           yearly.diverted_rows / NULLIF(yearly.scheduled_flight_rows, 0),
           4
       ) AS diversion_rate,
       yearly.avg_delay_minutes
FROM yearly
JOIN ranked USING (destination_canonical_std)
WHERE ranked.total_rank <= 10
ORDER BY ranked.total_rank, yearly.operating_year;

-- name: delay_reason_metrics
SELECT delay_reason_category,
       SUM(delayed_flight_rows) AS delayed_flight_rows,
       ROUND(
           SUM(delayed_flight_rows) / NULLIF(SUM(SUM(delayed_flight_rows)) OVER (), 0),
           4
       ) AS delay_reason_share
FROM v_metric_delay_reason_monthly
GROUP BY delay_reason_category
ORDER BY delayed_flight_rows DESC, delay_reason_category;

-- name: airline_yearly_demand_stability_metrics
-- 3개년 누적 여객 상위 10개 항공사의 연도별 수요와 운항 안정성을 비교한다.
WITH demand_yearly AS (
    SELECT LEFT(period_ym, 4) AS operating_year,
           COALESCE(
               NULLIF(
                   REGEXP_REPLACE(
                       REGEXP_REPLACE(TRIM(airline_name_raw), '\\([^)]*\\)', ''),
                       '[[:space:]/_-]',
                       ''
                   ),
                   ''
               ),
               '(NULL)'
           ) AS airline_std,
           SUM(passengers) AS passengers,
           SUM(operations) AS operations
    FROM v_airline_monthly
    WHERE period_ym IS NOT NULL
    GROUP BY LEFT(period_ym, 4),
             COALESCE(
                 NULLIF(
                     REGEXP_REPLACE(
                         REGEXP_REPLACE(TRIM(airline_name_raw), '\\([^)]*\\)', ''),
                         '[[:space:]/_-]',
                         ''
                     ),
                     ''
                 ),
                 '(NULL)'
             )
), operation_yearly AS (
    SELECT LEFT(operating_month, 4) AS operating_year,
           COALESCE(
               NULLIF(
                   REGEXP_REPLACE(
                       REGEXP_REPLACE(TRIM(airline_std), '\\([^)]*\\)', ''),
                       '[[:space:]/_-]',
                       ''
                   ),
                   ''
               ),
               '(NULL)'
           ) AS airline_std,
           SUM(scheduled_flight_rows) AS scheduled_flight_rows,
           SUM(status_operated_rows) AS status_operated_rows,
           SUM(status_delayed_rows) AS status_delayed_rows,
           SUM(time_delay_denominator_rows) AS time_delay_denominator_rows,
           SUM(time_delayed_15_rows) AS time_delayed_15_rows,
           SUM(cancelled_rows) AS cancelled_rows,
           SUM(diverted_rows) AS diverted_rows,
           ROUND(
               SUM(avg_delay_minutes * time_delayed_15_rows)
                   / NULLIF(SUM(time_delayed_15_rows), 0),
               2
           ) AS avg_delay_minutes
    FROM v_metric_operation_airline_monthly
    WHERE operating_month IS NOT NULL
    GROUP BY LEFT(operating_month, 4),
             COALESCE(
                 NULLIF(
                     REGEXP_REPLACE(
                         REGEXP_REPLACE(TRIM(airline_std), '\\([^)]*\\)', ''),
                         '[[:space:]/_-]',
                         ''
                     ),
                     ''
                 ),
                 '(NULL)'
             )
), demand_totals AS (
    SELECT airline_std,
           SUM(passengers) AS total_period_passengers
    FROM demand_yearly
    GROUP BY airline_std
), ranked AS (
    SELECT demand_totals.*,
           ROW_NUMBER() OVER (
               ORDER BY total_period_passengers DESC, airline_std
           ) AS total_rank
    FROM demand_totals
), demand_compared AS (
    SELECT current_year.*,
           previous_year.passengers AS previous_annual_passengers,
           ROUND(
               (current_year.passengers - previous_year.passengers)
                   / NULLIF(previous_year.passengers, 0),
               4
           ) AS annual_passenger_yoy_rate,
           previous_year.operations AS previous_annual_operations,
           ROUND(
               (current_year.operations - previous_year.operations)
                   / NULLIF(previous_year.operations, 0),
               4
           ) AS annual_operation_yoy_rate
    FROM demand_yearly AS current_year
    LEFT JOIN demand_yearly AS previous_year
      ON previous_year.airline_std = current_year.airline_std
     AND CAST(previous_year.operating_year AS UNSIGNED)
         = CAST(current_year.operating_year AS UNSIGNED) - 1
)
SELECT demand.operating_year, ranked.total_rank,
       ranked.total_period_passengers,
       demand.airline_std,
       demand.passengers, demand.operations,
       demand.previous_annual_passengers, demand.annual_passenger_yoy_rate,
       demand.previous_annual_operations, demand.annual_operation_yoy_rate,
       operation.scheduled_flight_rows,
       operation.status_operated_rows, operation.status_delayed_rows,
       ROUND(
           operation.status_delayed_rows / NULLIF(operation.status_operated_rows, 0),
           4
       ) AS status_delay_rate,
       operation.time_delay_denominator_rows, operation.time_delayed_15_rows,
       ROUND(
           operation.time_delayed_15_rows
               / NULLIF(operation.time_delay_denominator_rows, 0),
           4
       ) AS time_delay_15_rate,
       operation.cancelled_rows,
       ROUND(
           operation.cancelled_rows / NULLIF(operation.scheduled_flight_rows, 0),
           4
       ) AS cancellation_rate,
       operation.diverted_rows,
       ROUND(
           operation.diverted_rows / NULLIF(operation.scheduled_flight_rows, 0),
           4
       ) AS diversion_rate,
       operation.avg_delay_minutes
FROM demand_compared AS demand
JOIN ranked USING (airline_std)
JOIN operation_yearly AS operation
  ON operation.operating_year = demand.operating_year
 AND operation.airline_std = demand.airline_std
WHERE ranked.total_rank <= 10
ORDER BY ranked.total_rank, demand.operating_year;

-- name: demand_stability_airport_metrics
WITH standardized AS (
    SELECT period_ym,
           NULLIF(
               REGEXP_REPLACE(
                   REGEXP_REPLACE(TRIM(airport_name_raw), '\\([^)]*\\)', ''),
                   '[[:space:]/_-]',
                   ''
               ),
               ''
           ) AS airport_std,
           passengers
    FROM v_airport_monthly
    WHERE period_ym IS NOT NULL
), monthly AS (
    SELECT period_ym, airport_std,
           SUM(passengers) AS passengers
    FROM standardized
    GROUP BY period_ym, airport_std
), with_share AS (
    SELECT monthly.*,
           ROUND(passengers / NULLIF(SUM(passengers) OVER (PARTITION BY period_ym), 0), 4)
               AS passenger_share
    FROM monthly
), demand_metric AS (
SELECT current_month.period_ym, current_month.airport_std,
       current_month.passengers, current_month.passenger_share,
       previous_month.passengers AS previous_year_passengers,
       ROUND(
           (current_month.passengers - previous_month.passengers)
               / NULLIF(previous_month.passengers, 0),
           4
       ) AS passenger_yoy_rate
FROM with_share AS current_month
LEFT JOIN with_share AS previous_month
  ON previous_month.airport_std <=> current_month.airport_std
 AND previous_month.period_ym = DATE_FORMAT(
     DATE_SUB(STR_TO_DATE(CONCAT(current_month.period_ym, '01'), '%Y%m%d'), INTERVAL 1 YEAR),
     '%Y%m'
 )
)
SELECT d.period_ym, d.airport_std,
       d.passengers, d.passenger_share, d.passenger_yoy_rate,
       o.scheduled_flight_rows, o.status_operated_rows,
       o.status_delayed_rows, o.status_delay_rate,
       o.time_delay_denominator_rows, o.time_delayed_15_rows, o.time_delay_15_rate,
       o.cancelled_rows, o.cancellation_rate,
       o.diverted_rows, o.diversion_rate,
       o.avg_departure_gap_minutes, o.avg_delay_minutes, o.median_delay_minutes
FROM demand_metric AS d
JOIN v_metric_operation_airport_monthly AS o
  ON o.operating_month = d.period_ym
 AND o.airport_name_raw = d.airport_std
ORDER BY d.period_ym, d.airport_std;

-- name: yearly_demand_stability_destination_metrics
-- 3개년 누적 여객 상위 10개 목적지의 연도별 수요와 운항 안정성을 결합한다.
WITH demand_yearly AS (
    SELECT LEFT(period_ym, 4) AS operating_year,
           destination_canonical_std,
           SUM(passengers) AS passengers,
           SUM(operations) AS operations
    FROM v_metric_demand_destination_monthly
    GROUP BY LEFT(period_ym, 4), destination_canonical_std
), demand_totals AS (
    SELECT destination_canonical_std,
           SUM(passengers) AS total_period_passengers
    FROM demand_yearly
    GROUP BY destination_canonical_std
), ranked AS (
    SELECT demand_totals.*,
           ROW_NUMBER() OVER (
               ORDER BY total_period_passengers DESC, destination_canonical_std
           ) AS total_rank
    FROM demand_totals
), demand_with_share AS (
    SELECT demand_yearly.*,
           ROUND(
               passengers / NULLIF(SUM(passengers) OVER (PARTITION BY operating_year), 0),
               4
           ) AS passenger_share
    FROM demand_yearly
), demand_compared AS (
    SELECT current_year.*,
           previous_year.passengers AS previous_annual_passengers,
           ROUND(
               (current_year.passengers - previous_year.passengers)
                   / NULLIF(previous_year.passengers, 0),
               4
           ) AS annual_passenger_yoy_rate
    FROM demand_with_share AS current_year
    LEFT JOIN demand_with_share AS previous_year
      ON previous_year.destination_canonical_std <=> current_year.destination_canonical_std
     AND CAST(previous_year.operating_year AS UNSIGNED)
         = CAST(current_year.operating_year AS UNSIGNED) - 1
), operation_yearly AS (
    SELECT LEFT(operating_month, 4) AS operating_year,
           destination_canonical_std,
           SUM(scheduled_flight_rows) AS scheduled_flight_rows,
           SUM(status_operated_rows) AS status_operated_rows,
           SUM(status_delayed_rows) AS status_delayed_rows,
           SUM(time_delay_denominator_rows) AS time_delay_denominator_rows,
           SUM(time_delayed_15_rows) AS time_delayed_15_rows,
           SUM(cancelled_rows) AS cancelled_rows,
           SUM(diverted_rows) AS diverted_rows,
           ROUND(
               SUM(avg_delay_minutes * time_delayed_15_rows)
                   / NULLIF(SUM(time_delayed_15_rows), 0),
               2
           ) AS avg_delay_minutes
    FROM v_metric_operation_destination_monthly
    GROUP BY LEFT(operating_month, 4), destination_canonical_std
)
SELECT demand.operating_year, ranked.total_rank,
       ranked.total_period_passengers,
       demand.destination_canonical_std,
       demand.passengers, demand.operations,
       demand.passenger_share, demand.annual_passenger_yoy_rate,
       operation.scheduled_flight_rows,
       operation.status_operated_rows, operation.status_delayed_rows,
       ROUND(
           operation.status_delayed_rows / NULLIF(operation.status_operated_rows, 0),
           4
       ) AS status_delay_rate,
       operation.time_delay_denominator_rows, operation.time_delayed_15_rows,
       ROUND(
           operation.time_delayed_15_rows
               / NULLIF(operation.time_delay_denominator_rows, 0),
           4
       ) AS time_delay_15_rate,
       operation.cancelled_rows,
       ROUND(
           operation.cancelled_rows / NULLIF(operation.scheduled_flight_rows, 0),
           4
       ) AS cancellation_rate,
       operation.diverted_rows,
       ROUND(
           operation.diverted_rows / NULLIF(operation.scheduled_flight_rows, 0),
           4
       ) AS diversion_rate,
       operation.avg_delay_minutes
FROM demand_compared AS demand
JOIN ranked USING (destination_canonical_std)
JOIN operation_yearly AS operation
  ON operation.operating_year = demand.operating_year
 AND operation.destination_canonical_std = demand.destination_canonical_std
WHERE ranked.total_rank <= 10
ORDER BY ranked.total_rank, demand.operating_year;

-- name: destination_trend_stability_metrics
-- 누적·최신 연도 수요·최근 증가 상위 목적지를 합쳐 연도별 수요와 운항 안정성을 비교한다.
WITH demand_yearly AS (
    SELECT LEFT(period_ym, 4) AS operating_year,
           destination_canonical_std,
           SUM(passengers) AS passengers,
           SUM(operations) AS operations
    FROM v_metric_demand_destination_monthly
    GROUP BY LEFT(period_ym, 4), destination_canonical_std
), bounds AS (
    SELECT MAX(operating_year) AS latest_year
    FROM demand_yearly
), cumulative_totals AS (
    SELECT destination_canonical_std,
           SUM(passengers) AS total_period_passengers
    FROM demand_yearly
    GROUP BY destination_canonical_std
), cumulative_ranked AS (
    SELECT cumulative_totals.*,
           ROW_NUMBER() OVER (
               ORDER BY total_period_passengers DESC, destination_canonical_std
           ) AS cumulative_rank
    FROM cumulative_totals
), latest_year_ranked AS (
    SELECT demand.destination_canonical_std,
           demand.passengers AS latest_year_passengers,
           ROW_NUMBER() OVER (
               ORDER BY demand.passengers DESC, demand.destination_canonical_std
           ) AS latest_year_rank
    FROM demand_yearly AS demand
    JOIN bounds
      ON demand.operating_year = bounds.latest_year
), growth_values AS (
    SELECT current_year.destination_canonical_std,
           current_year.passengers - COALESCE(previous_year.passengers, 0)
               AS latest_year_passenger_growth
    FROM demand_yearly AS current_year
    CROSS JOIN bounds
    LEFT JOIN demand_yearly AS previous_year
      ON previous_year.destination_canonical_std = current_year.destination_canonical_std
     AND CAST(previous_year.operating_year AS UNSIGNED)
         = CAST(current_year.operating_year AS UNSIGNED) - 1
    WHERE current_year.operating_year = bounds.latest_year
), growth_ranked AS (
    SELECT growth_values.*,
           ROW_NUMBER() OVER (
               ORDER BY latest_year_passenger_growth DESC, destination_canonical_std
           ) AS growth_rank
    FROM growth_values
    WHERE latest_year_passenger_growth > 0
), candidates AS (
    SELECT cumulative.destination_canonical_std,
           cumulative.total_period_passengers,
           cumulative.cumulative_rank,
           latest.latest_year_rank,
           growth.growth_rank,
           growth.latest_year_passenger_growth,
           CONCAT_WS(
               ' + ',
               CASE WHEN cumulative.cumulative_rank <= 10 THEN '누적 상위' END,
               CASE WHEN latest.latest_year_rank <= 10 THEN '최신 연도 수요 상위' END,
               CASE WHEN growth.growth_rank <= 10 THEN '최근 성장 상위' END
           ) AS selection_reason
    FROM cumulative_ranked AS cumulative
    LEFT JOIN latest_year_ranked AS latest
      ON latest.destination_canonical_std = cumulative.destination_canonical_std
    LEFT JOIN growth_ranked AS growth
      ON growth.destination_canonical_std = cumulative.destination_canonical_std
    WHERE cumulative.cumulative_rank <= 10
       OR latest.latest_year_rank <= 10
       OR growth.growth_rank <= 10
), demand_compared AS (
    SELECT current_year.*,
           previous_year.passengers AS previous_annual_passengers,
           ROUND(
               (current_year.passengers - previous_year.passengers)
                   / NULLIF(previous_year.passengers, 0),
               4
           ) AS annual_passenger_yoy_rate
    FROM demand_yearly AS current_year
    LEFT JOIN demand_yearly AS previous_year
      ON previous_year.destination_canonical_std = current_year.destination_canonical_std
     AND CAST(previous_year.operating_year AS UNSIGNED)
         = CAST(current_year.operating_year AS UNSIGNED) - 1
), operation_yearly AS (
    SELECT LEFT(operating_month, 4) AS operating_year,
           destination_canonical_std,
           SUM(scheduled_flight_rows) AS scheduled_flight_rows,
           SUM(status_operated_rows) AS status_operated_rows,
           SUM(status_delayed_rows) AS status_delayed_rows,
           SUM(time_delay_denominator_rows) AS time_delay_denominator_rows,
           SUM(time_delayed_15_rows) AS time_delayed_15_rows,
           SUM(cancelled_rows) AS cancelled_rows,
           SUM(diverted_rows) AS diverted_rows,
           ROUND(
               SUM(avg_delay_minutes * time_delayed_15_rows)
                   / NULLIF(SUM(time_delayed_15_rows), 0),
               2
           ) AS avg_delay_minutes
    FROM v_metric_operation_destination_monthly
    GROUP BY LEFT(operating_month, 4), destination_canonical_std
)
SELECT demand.operating_year,
       candidates.destination_canonical_std,
       candidates.selection_reason,
       candidates.cumulative_rank,
       candidates.latest_year_rank,
       candidates.growth_rank,
       candidates.total_period_passengers,
       candidates.latest_year_passenger_growth,
       demand.passengers, demand.operations,
       demand.previous_annual_passengers, demand.annual_passenger_yoy_rate,
       operation.scheduled_flight_rows,
       operation.status_operated_rows, operation.status_delayed_rows,
       ROUND(
           operation.status_delayed_rows / NULLIF(operation.status_operated_rows, 0),
           4
       ) AS status_delay_rate,
       operation.time_delay_denominator_rows, operation.time_delayed_15_rows,
       ROUND(
           operation.time_delayed_15_rows
               / NULLIF(operation.time_delay_denominator_rows, 0),
           4
       ) AS time_delay_15_rate,
       operation.cancelled_rows,
       ROUND(
           operation.cancelled_rows / NULLIF(operation.scheduled_flight_rows, 0),
           4
       ) AS cancellation_rate,
       operation.diverted_rows,
       ROUND(
           operation.diverted_rows / NULLIF(operation.scheduled_flight_rows, 0),
           4
       ) AS diversion_rate,
       operation.avg_delay_minutes
FROM candidates
JOIN demand_compared AS demand
  ON demand.destination_canonical_std = candidates.destination_canonical_std
JOIN operation_yearly AS operation
  ON operation.operating_year = demand.operating_year
 AND operation.destination_canonical_std = demand.destination_canonical_std
ORDER BY candidates.cumulative_rank, candidates.latest_year_rank,
         candidates.growth_rank, demand.operating_year;

