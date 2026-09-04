-- name: eda_source_coverage
-- 03에서 사용하는 분석용 뷰의 기간과 행 범위를 확인한다.
SELECT 'v_route_monthly' AS dataset,
       MIN(period_ym) AS first_period_ym, MAX(period_ym) AS last_period_ym,
       COUNT(DISTINCT period_ym) AS month_count, COUNT(*) AS rows_count
FROM v_route_monthly
UNION ALL
SELECT 'v_airline_monthly', MIN(period_ym), MAX(period_ym), COUNT(DISTINCT period_ym), COUNT(*)
FROM v_airline_monthly
UNION ALL
SELECT 'v_airport_monthly', MIN(period_ym), MAX(period_ym), COUNT(DISTINCT period_ym), COUNT(*)
FROM v_airport_monthly
UNION ALL
SELECT 'v_country_monthly', MIN(period_ym), MAX(period_ym), COUNT(DISTINCT period_ym), COUNT(*)
FROM v_country_monthly
UNION ALL
SELECT 'v_flight_analysis', MIN(operating_month), MAX(operating_month),
       COUNT(DISTINCT operating_month), COUNT(*)
FROM v_flight_analysis
ORDER BY dataset;

-- name: incheon_gimpo_demand_coverage
-- 전국 국제선 출발 여객 중 인천·김포가 차지하는 월별 비중을 확인한다.
WITH monthly AS (
    SELECT period_ym,
           SUM(CASE WHEN airport_name_raw IN ('인천(ICN)', '김포(GMP)') THEN passengers ELSE 0 END)
               AS incheon_gimpo_passengers,
           SUM(passengers) AS national_passengers
    FROM v_airport_monthly
    GROUP BY period_ym
)
SELECT period_ym, incheon_gimpo_passengers, national_passengers,
       ROUND(incheon_gimpo_passengers / NULLIF(national_passengers, 0), 4)
           AS incheon_gimpo_passenger_share
FROM monthly
ORDER BY period_ym;

-- name: incheon_gimpo_operation_coverage
-- 전국 국제선 출발 운항 중 인천·김포가 차지하는 월별 비중을 확인한다.
WITH monthly AS (
    SELECT period_ym,
           SUM(CASE WHEN origin_airport_raw IN ('인천(ICN)', '김포(GMP)') THEN operations ELSE 0 END)
               AS incheon_gimpo_operations,
           SUM(operations) AS national_operations
    FROM v_route_monthly
    WHERE is_international = TRUE
    GROUP BY period_ym
)
SELECT period_ym, incheon_gimpo_operations, national_operations,
       ROUND(incheon_gimpo_operations / NULLIF(national_operations, 0), 4)
           AS incheon_gimpo_operation_share
FROM monthly
ORDER BY period_ym;

-- name: flight_scope_coverage
-- 전체 출발 로그와 여객편의 국내·국제·미확정·충돌 범위를 공항별로 확인한다.
SELECT airport_name_raw,
       COUNT(*) AS all_departure_log_rows,
       SUM(is_passenger) AS passenger_rows,
       SUM(is_passenger AND flight_scope_std = 'domestic') AS domestic_passenger_rows,
       SUM(is_passenger AND flight_scope_std = 'international') AS international_passenger_rows,
       SUM(is_passenger AND flight_scope_std = 'unresolved') AS unresolved_passenger_rows,
       SUM(is_passenger AND flight_scope_std = 'reference_conflict') AS reference_conflict_passenger_rows,
       ROUND(
           SUM(is_passenger AND flight_scope_std = 'international') / NULLIF(SUM(is_passenger), 0),
           4
       ) AS international_passenger_share
FROM v_flight_analysis
GROUP BY airport_name_raw
ORDER BY airport_name_raw;

-- name: flight_scope_profile
-- 공항·서비스·상태·국내외 범위 구성을 분석 필터 적용 전에 확인한다.
WITH grouped AS (
    SELECT airport_name_raw,
           COALESCE(service_type_raw, '(NULL)') AS service_type_raw,
           COALESCE(status_raw, '(NULL)') AS status_raw,
           flight_scope_std,
           COUNT(*) AS flight_rows
    FROM v_flight_analysis
    GROUP BY airport_name_raw,
             COALESCE(service_type_raw, '(NULL)'),
             COALESCE(status_raw, '(NULL)'),
             flight_scope_std
)
SELECT airport_name_raw, service_type_raw, status_raw, flight_scope_std, flight_rows,
       SUM(flight_rows) OVER (PARTITION BY airport_name_raw) AS airport_total_rows,
       ROUND(flight_rows / NULLIF(SUM(flight_rows) OVER (PARTITION BY airport_name_raw), 0), 4)
           AS share_within_airport
FROM grouped
ORDER BY airport_name_raw, flight_rows DESC, service_type_raw, status_raw, flight_scope_std;

-- name: international_reference_evidence_summary
-- 02에서 보강한 국내 공항·국제선 노선·별칭 참조에 따른 여객 목적지 분류를 요약한다.
WITH passenger_destinations AS (
    SELECT destination_std, destination_canonical_std, flight_scope_std,
           scope_reference_source, COUNT(*) AS flight_rows
    FROM v_flight_analysis
    WHERE is_passenger
    GROUP BY destination_std, destination_canonical_std, flight_scope_std, scope_reference_source
)
SELECT flight_scope_std,
       COUNT(*) AS destination_group_count,
       SUM(flight_rows) AS flight_rows,
       ROUND(SUM(flight_rows) / NULLIF(SUM(SUM(flight_rows)) OVER (), 0), 4) AS flight_row_share
FROM passenger_destinations
GROUP BY flight_scope_std
ORDER BY FIELD(flight_scope_std, 'international', 'domestic', 'unresolved', 'reference_conflict');

-- name: international_reference_review_destinations
-- 미확정·참조 충돌 여객 목적지를 절단하지 않고 검토한다.
SELECT destination_raw, destination_std, destination_canonical_std,
       flight_scope_std, scope_reference_source,
       COUNT(*) AS flight_rows
FROM v_flight_analysis
WHERE is_passenger
  AND flight_scope_std IN ('unresolved', 'reference_conflict')
GROUP BY destination_raw, destination_std, destination_canonical_std,
         flight_scope_std, scope_reference_source
ORDER BY FIELD(flight_scope_std, 'reference_conflict', 'unresolved'),
         flight_rows DESC, destination_raw;

-- name: monthly_demand_trend
-- 국제선 출발 노선의 월별 여객·운항 추이를 확인한다.
SELECT period_ym,
       SUM(passengers) AS passengers,
       SUM(operations) AS operations,
       ROUND(SUM(passengers) / NULLIF(SUM(operations), 0), 2) AS passengers_per_operation
FROM v_route_monthly
WHERE is_international = TRUE
GROUP BY period_ym
ORDER BY period_ym;

-- name: yearly_demand_summary
-- 연도별 국제선 출발 여객·운항과 전년 대비 변화를 확인한다.
WITH yearly AS (
    SELECT LEFT(period_ym, 4) AS operating_year,
           SUM(passengers) AS passengers,
           SUM(operations) AS operations
    FROM v_route_monthly
    WHERE is_international = TRUE
    GROUP BY LEFT(period_ym, 4)
), compared AS (
    SELECT operating_year, passengers, operations,
           LAG(passengers) OVER (ORDER BY operating_year) AS previous_year_passengers,
           LAG(operations) OVER (ORDER BY operating_year) AS previous_year_operations
    FROM yearly
)
SELECT operating_year, passengers, operations,
       ROUND(passengers / NULLIF(operations, 0), 2) AS passengers_per_operation,
       ROUND((passengers - previous_year_passengers) / NULLIF(previous_year_passengers, 0), 4)
           AS passenger_yoy_rate,
       ROUND((operations - previous_year_operations) / NULLIF(previous_year_operations, 0), 4)
           AS operation_yoy_rate
FROM compared
ORDER BY operating_year;

-- name: seasonal_demand_profile
-- 3개 연도의 같은 달을 묶어 월별 계절성 범위를 확인한다.
WITH monthly AS (
    SELECT period_ym,
           SUM(passengers) AS passengers,
           SUM(operations) AS operations
    FROM v_route_monthly
    WHERE is_international = TRUE
    GROUP BY period_ym
), indexed AS (
    SELECT period_ym, passengers, operations,
           passengers / NULLIF(AVG(passengers) OVER (PARTITION BY LEFT(period_ym, 4)), 0)
               AS passenger_seasonal_index,
           operations / NULLIF(AVG(operations) OVER (PARTITION BY LEFT(period_ym, 4)), 0)
               AS operation_seasonal_index
    FROM monthly
)
SELECT RIGHT(period_ym, 2) AS calendar_month,
       COUNT(*) AS observed_years,
       ROUND(AVG(passengers), 0) AS avg_passengers,
       MIN(passengers) AS min_passengers,
       MAX(passengers) AS max_passengers,
       ROUND(AVG(passenger_seasonal_index), 4) AS avg_passenger_seasonal_index,
       ROUND(AVG(operations), 0) AS avg_operations,
       MIN(operations) AS min_operations,
       MAX(operations) AS max_operations,
       ROUND(AVG(operation_seasonal_index), 4) AS avg_operation_seasonal_index
FROM indexed
GROUP BY RIGHT(period_ym, 2)
ORDER BY calendar_month;

-- name: airport_demand_distribution
-- 한국 출발공항별 국제선 출발 여객 분포를 확인한다.
SELECT airport_name_raw,
       SUM(passengers) AS passengers,
       COUNT(DISTINCT period_ym) AS observed_months,
       ROUND(SUM(passengers) / NULLIF(SUM(SUM(passengers)) OVER (), 0), 4) AS passenger_share
FROM v_airport_monthly
GROUP BY airport_name_raw
ORDER BY passengers DESC, airport_name_raw;

-- name: country_demand_distribution
-- 국가별 국제선 출발 여객 상위 분포를 확인한다.
SELECT region_raw, country_raw,
       SUM(passengers) AS passengers,
       COUNT(DISTINCT period_ym) AS observed_months,
       ROUND(SUM(passengers) / NULLIF(SUM(SUM(passengers)) OVER (), 0), 4) AS passenger_share
FROM v_country_monthly
GROUP BY region_raw, country_raw
ORDER BY passengers DESC, region_raw, country_raw
LIMIT 30;

-- name: destination_demand_distribution
-- 목적지별 국제선 출발 여객·운항 상위 분포를 확인한다.
SELECT destination_airport_raw,
       SUM(passengers) AS passengers,
       SUM(operations) AS operations,
       COUNT(DISTINCT period_ym) AS observed_months,
       ROUND(SUM(passengers) / NULLIF(SUM(SUM(passengers)) OVER (), 0), 4) AS passenger_share,
       ROUND(SUM(passengers) / NULLIF(SUM(operations), 0), 2) AS passengers_per_operation
FROM v_route_monthly
WHERE is_international = TRUE
GROUP BY destination_airport_raw
ORDER BY passengers DESC, destination_airport_raw
LIMIT 30;

-- name: route_demand_distribution
-- 출발공항·목적지 노선별 국제선 출발 여객·운항 상위 분포를 확인한다.
SELECT origin_airport_raw, destination_airport_raw,
       SUM(passengers) AS passengers,
       SUM(operations) AS operations,
       COUNT(DISTINCT period_ym) AS observed_months,
       ROUND(SUM(passengers) / NULLIF(SUM(SUM(passengers)) OVER (), 0), 4) AS passenger_share,
       ROUND(SUM(passengers) / NULLIF(SUM(operations), 0), 2) AS passengers_per_operation
FROM v_route_monthly
WHERE is_international = TRUE
GROUP BY origin_airport_raw, destination_airport_raw
ORDER BY passengers DESC, origin_airport_raw, destination_airport_raw
LIMIT 30;

-- name: airline_demand_distribution
-- 항공사별 국제선 출발 여객·운항 상위 분포를 확인한다.
SELECT airline_name_raw,
       SUM(passengers) AS passengers,
       SUM(operations) AS operations,
       COUNT(DISTINCT period_ym) AS observed_months,
       ROUND(SUM(passengers) / NULLIF(SUM(SUM(passengers)) OVER (), 0), 4) AS passenger_share,
       ROUND(SUM(passengers) / NULLIF(SUM(operations), 0), 2) AS passengers_per_operation
FROM v_airline_monthly
GROUP BY airline_name_raw
ORDER BY passengers DESC, airline_name_raw
LIMIT 30;

-- name: status_time_relationship
-- 여객편의 상태값과 보정 전 실제·계획 시간차 관계를 확인한다.
SELECT airport_name_raw, COALESCE(status_raw, '(NULL)') AS status_raw,
       COUNT(*) AS passenger_rows,
       SUM(is_time_calculable) AS time_calculable_rows,
       ROUND(SUM(is_time_calculable) / NULLIF(COUNT(*), 0), 4) AS time_calculable_rate,
       MIN(CASE WHEN is_time_calculable THEN raw_gap_minutes END) AS min_raw_gap_minutes,
       MAX(CASE WHEN is_time_calculable THEN raw_gap_minutes END) AS max_raw_gap_minutes,
       ROUND(AVG(CASE WHEN is_time_calculable THEN raw_gap_minutes END), 2) AS avg_raw_gap_minutes,
       SUM(is_time_calculable AND raw_gap_minutes < 0) AS negative_gap_rows,
       SUM(is_time_calculable AND raw_gap_minutes = 0) AS zero_gap_rows,
       SUM(is_time_calculable AND raw_gap_minutes > 0 AND raw_gap_minutes < 15) AS gap_1_to_14_rows,
       SUM(is_time_calculable AND raw_gap_minutes >= 15 AND raw_gap_minutes < 30) AS gap_15_to_29_rows,
       SUM(is_time_calculable AND raw_gap_minutes >= 30) AS gap_at_least_30_rows
FROM v_flight_analysis
WHERE is_passenger
  AND is_international = TRUE
GROUP BY airport_name_raw, COALESCE(status_raw, '(NULL)')
ORDER BY airport_name_raw, passenger_rows DESC, status_raw;

-- name: scheduled_estimated_actual_relationship
-- 상태별 계획·예상·실제 시각의 계산 가능성과 보정 전 차이를 함께 확인한다.
SELECT airport_name_raw, COALESCE(status_raw, '(NULL)') AS status_raw,
       COUNT(*) AS passenger_rows,
       SUM(is_scheduled_valid AND is_estimated_valid) AS scheduled_estimated_rows,
       ROUND(AVG(CASE WHEN is_scheduled_valid AND is_estimated_valid THEN est_gap_minutes END), 2)
           AS avg_estimated_minus_scheduled,
       SUM(is_scheduled_valid AND is_estimated_valid AND est_gap_minutes < 0)
           AS estimated_before_scheduled_rows,
       SUM(is_estimated_valid AND is_actual_valid) AS estimated_actual_rows,
       ROUND(AVG(CASE WHEN is_estimated_valid AND is_actual_valid
                      THEN CAST(actual_minutes AS SIGNED) - CAST(estimated_minutes AS SIGNED) END), 2)
           AS avg_actual_minus_estimated,
       SUM(is_estimated_valid AND is_actual_valid
           AND CAST(actual_minutes AS SIGNED) - CAST(estimated_minutes AS SIGNED) < 0)
           AS actual_before_estimated_rows
FROM v_flight_analysis
WHERE is_passenger
  AND is_international = TRUE
GROUP BY airport_name_raw, COALESCE(status_raw, '(NULL)')
ORDER BY airport_name_raw, passenger_rows DESC, status_raw;

-- name: denominator_candidate_profile
-- 지연률 분모 후보별 포함 행 수만 비교하며 최종 분모는 정하지 않는다.
SELECT airport_name_raw,
       COUNT(*) AS passenger_rows,
       SUM(is_denominator) AS status_operated_rows,
       SUM(is_time_calculable) AS time_calculable_rows,
       SUM(is_denominator AND is_time_calculable) AS status_operated_time_calculable_rows,
       SUM(NOT is_cancelled) AS not_cancelled_rows,
       SUM(is_cancelled) AS cancelled_rows,
       SUM(is_diverted) AS diverted_rows,
       SUM(is_status_unknown) AS status_unknown_rows
FROM v_flight_analysis
WHERE is_passenger
  AND is_international = TRUE
GROUP BY airport_name_raw
ORDER BY airport_name_raw;

-- name: delay_threshold_sensitivity
-- 운항 상태·시간 계산 가능 여객편에서 시간 임계값과 상태값의 일치 정도를 비교한다.
WITH thresholds AS (
    SELECT 0 AS threshold_minutes
    UNION ALL SELECT 5
    UNION ALL SELECT 10
    UNION ALL SELECT 15
    UNION ALL SELECT 20
    UNION ALL SELECT 30
    UNION ALL SELECT 60
), scoped AS (
    SELECT airport_name_raw, status_raw, raw_gap_minutes
    FROM v_flight_analysis
    WHERE is_passenger
      AND is_international = TRUE
      AND is_denominator
      AND is_time_calculable
), aggregated AS (
    SELECT airport_name_raw,
           COUNT(*) AS candidate_denominator_rows,
           SUM(status_raw = '지연') AS status_delayed_rows,
           SUM(raw_gap_minutes >= 0) AS gap_at_least_0_rows,
           SUM(raw_gap_minutes >= 5) AS gap_at_least_5_rows,
           SUM(raw_gap_minutes >= 10) AS gap_at_least_10_rows,
           SUM(raw_gap_minutes >= 15) AS gap_at_least_15_rows,
           SUM(raw_gap_minutes >= 20) AS gap_at_least_20_rows,
           SUM(raw_gap_minutes >= 30) AS gap_at_least_30_rows,
           SUM(raw_gap_minutes >= 60) AS gap_at_least_60_rows,
           SUM(status_raw = '지연' AND raw_gap_minutes >= 0) AS both_at_least_0_rows,
           SUM(status_raw = '지연' AND raw_gap_minutes >= 5) AS both_at_least_5_rows,
           SUM(status_raw = '지연' AND raw_gap_minutes >= 10) AS both_at_least_10_rows,
           SUM(status_raw = '지연' AND raw_gap_minutes >= 15) AS both_at_least_15_rows,
           SUM(status_raw = '지연' AND raw_gap_minutes >= 20) AS both_at_least_20_rows,
           SUM(status_raw = '지연' AND raw_gap_minutes >= 30) AS both_at_least_30_rows,
           SUM(status_raw = '지연' AND raw_gap_minutes >= 60) AS both_at_least_60_rows,
           SUM(status_raw = '출발' AND raw_gap_minutes >= 0) AS threshold_only_at_least_0_rows,
           SUM(status_raw = '출발' AND raw_gap_minutes >= 5) AS threshold_only_at_least_5_rows,
           SUM(status_raw = '출발' AND raw_gap_minutes >= 10) AS threshold_only_at_least_10_rows,
           SUM(status_raw = '출발' AND raw_gap_minutes >= 15) AS threshold_only_at_least_15_rows,
           SUM(status_raw = '출발' AND raw_gap_minutes >= 20) AS threshold_only_at_least_20_rows,
           SUM(status_raw = '출발' AND raw_gap_minutes >= 30) AS threshold_only_at_least_30_rows,
           SUM(status_raw = '출발' AND raw_gap_minutes >= 60) AS threshold_only_at_least_60_rows
    FROM scoped
    GROUP BY airport_name_raw
)
SELECT a.airport_name_raw, t.threshold_minutes,
       a.candidate_denominator_rows,
       a.status_delayed_rows,
       CASE t.threshold_minutes
           WHEN 0 THEN a.gap_at_least_0_rows WHEN 5 THEN a.gap_at_least_5_rows
           WHEN 10 THEN a.gap_at_least_10_rows WHEN 15 THEN a.gap_at_least_15_rows
           WHEN 20 THEN a.gap_at_least_20_rows WHEN 30 THEN a.gap_at_least_30_rows
           WHEN 60 THEN a.gap_at_least_60_rows
       END AS threshold_delayed_rows,
       ROUND((CASE t.threshold_minutes
           WHEN 0 THEN a.gap_at_least_0_rows WHEN 5 THEN a.gap_at_least_5_rows
           WHEN 10 THEN a.gap_at_least_10_rows WHEN 15 THEN a.gap_at_least_15_rows
           WHEN 20 THEN a.gap_at_least_20_rows WHEN 30 THEN a.gap_at_least_30_rows
           WHEN 60 THEN a.gap_at_least_60_rows
       END) / NULLIF(a.candidate_denominator_rows, 0), 4)
           AS threshold_delayed_rate,
       CASE t.threshold_minutes
           WHEN 0 THEN a.both_at_least_0_rows WHEN 5 THEN a.both_at_least_5_rows
           WHEN 10 THEN a.both_at_least_10_rows WHEN 15 THEN a.both_at_least_15_rows
           WHEN 20 THEN a.both_at_least_20_rows WHEN 30 THEN a.both_at_least_30_rows
           WHEN 60 THEN a.both_at_least_60_rows
       END AS both_delayed_rows,
       a.status_delayed_rows - (CASE t.threshold_minutes
           WHEN 0 THEN a.both_at_least_0_rows WHEN 5 THEN a.both_at_least_5_rows
           WHEN 10 THEN a.both_at_least_10_rows WHEN 15 THEN a.both_at_least_15_rows
           WHEN 20 THEN a.both_at_least_20_rows WHEN 30 THEN a.both_at_least_30_rows
           WHEN 60 THEN a.both_at_least_60_rows
       END) AS status_only_rows,
       CASE t.threshold_minutes
           WHEN 0 THEN a.threshold_only_at_least_0_rows WHEN 5 THEN a.threshold_only_at_least_5_rows
           WHEN 10 THEN a.threshold_only_at_least_10_rows WHEN 15 THEN a.threshold_only_at_least_15_rows
           WHEN 20 THEN a.threshold_only_at_least_20_rows WHEN 30 THEN a.threshold_only_at_least_30_rows
           WHEN 60 THEN a.threshold_only_at_least_60_rows
       END AS threshold_only_rows
FROM aggregated AS a
CROSS JOIN thresholds AS t
ORDER BY a.airport_name_raw, t.threshold_minutes;

-- name: midnight_negative_gap_profile
-- 음수 원시 시간차를 크기별로 나눠 자정 넘김 후보와 조기 출발 가능성을 분리해 본다.
SELECT airport_name_raw, COALESCE(status_raw, '(NULL)') AS status_raw,
       CASE
           WHEN raw_gap_minutes <= -720 THEN 'at_or_below_minus_720'
           WHEN raw_gap_minutes BETWEEN -719 AND -61 THEN 'minus_719_to_minus_61'
           ELSE 'minus_60_to_minus_1'
       END AS negative_gap_band,
       COUNT(*) AS flight_rows,
       MIN(raw_gap_minutes) AS min_raw_gap_minutes,
       MAX(raw_gap_minutes) AS max_raw_gap_minutes,
       MIN(scheduled_hour) AS min_scheduled_hour,
       MAX(scheduled_hour) AS max_scheduled_hour
FROM v_flight_analysis
WHERE is_passenger
  AND is_international = TRUE
  AND is_time_calculable
  AND raw_gap_minutes < 0
GROUP BY airport_name_raw, COALESCE(status_raw, '(NULL)'),
         CASE
             WHEN raw_gap_minutes <= -720 THEN 'at_or_below_minus_720'
             WHEN raw_gap_minutes BETWEEN -719 AND -61 THEN 'minus_719_to_minus_61'
             ELSE 'minus_60_to_minus_1'
         END
ORDER BY airport_name_raw, status_raw,
         FIELD(negative_gap_band, 'at_or_below_minus_720', 'minus_719_to_minus_61', 'minus_60_to_minus_1');

-- name: midnight_adjustment_sensitivity
-- 자정 보정 후보별 결과 차이만 비교하며 어떤 규칙도 확정하지 않는다.
WITH scoped AS (
    SELECT airport_name_raw, raw_gap_minutes
    FROM v_flight_analysis
    WHERE is_passenger
      AND is_international = TRUE
      AND is_denominator
      AND is_time_calculable
), scenarios AS (
    SELECT airport_name_raw,
           COUNT(*) AS candidate_rows,
           SUM(raw_gap_minutes) AS raw_gap_sum,
           SUM(raw_gap_minutes < 0) AS negative_rows,
           SUM(raw_gap_minutes <= -720) AS at_or_below_minus_720_rows,
           SUM(raw_gap_minutes >= 15) AS raw_gap_at_least_15_rows,
           SUM(raw_gap_minutes >= 30) AS raw_gap_at_least_30_rows,
           SUM(CASE WHEN raw_gap_minutes < 0 THEN raw_gap_minutes + 1440 ELSE raw_gap_minutes END >= 15) AS all_negative_gap_at_least_15_rows,
           SUM(CASE WHEN raw_gap_minutes < 0 THEN raw_gap_minutes + 1440 ELSE raw_gap_minutes END >= 30) AS all_negative_gap_at_least_30_rows,
           SUM(CASE WHEN raw_gap_minutes <= -720 THEN raw_gap_minutes + 1440 ELSE raw_gap_minutes END >= 15) AS large_negative_gap_at_least_15_rows,
           SUM(CASE WHEN raw_gap_minutes <= -720 THEN raw_gap_minutes + 1440 ELSE raw_gap_minutes END >= 30) AS large_negative_gap_at_least_30_rows
    FROM scoped
    GROUP BY airport_name_raw
)
SELECT airport_name_raw, 'raw_no_adjustment' AS adjustment_rule,
       candidate_rows, 0 AS adjusted_rows, negative_rows AS remaining_negative_rows,
       ROUND(raw_gap_sum / NULLIF(candidate_rows, 0), 2) AS avg_scenario_gap_minutes,
       raw_gap_at_least_15_rows AS gap_at_least_15_rows,
       raw_gap_at_least_30_rows AS gap_at_least_30_rows
FROM scenarios
UNION ALL
SELECT airport_name_raw, 'add_1440_to_all_negative',
       candidate_rows, negative_rows, 0,
       ROUND((raw_gap_sum + 1440 * negative_rows) / NULLIF(candidate_rows, 0), 2),
       all_negative_gap_at_least_15_rows, all_negative_gap_at_least_30_rows
FROM scenarios
UNION ALL
SELECT airport_name_raw, 'add_1440_if_gap_le_minus_720',
       candidate_rows, at_or_below_minus_720_rows,
       negative_rows - at_or_below_minus_720_rows,
       ROUND((raw_gap_sum + 1440 * at_or_below_minus_720_rows) / NULLIF(candidate_rows, 0), 2),
       large_negative_gap_at_least_15_rows, large_negative_gap_at_least_30_rows
FROM scenarios
ORDER BY airport_name_raw,
         FIELD(adjustment_rule,
               'raw_no_adjustment',
               'add_1440_if_gap_le_minus_720',
               'add_1440_to_all_negative');

-- name: delay_reason_coverage
-- 여객편의 상태별 지연사유 입력 범위를 확인한다.
SELECT airport_name_raw, COALESCE(status_raw, '(NULL)') AS status_raw,
       COUNT(*) AS passenger_rows,
       SUM(delay_reason_raw IS NOT NULL AND TRIM(delay_reason_raw) <> '') AS reason_filled_rows,
       ROUND(
           SUM(delay_reason_raw IS NOT NULL AND TRIM(delay_reason_raw) <> '') / NULLIF(COUNT(*), 0),
           4
       ) AS reason_filled_rate
FROM v_flight_analysis
WHERE is_passenger
  AND is_international = TRUE
GROUP BY airport_name_raw, COALESCE(status_raw, '(NULL)')
ORDER BY airport_name_raw, passenger_rows DESC, status_raw;

-- name: delay_reason_distribution
-- 입력된 지연사유를 표준 사유·운항결과와 상태값별로 확인한다.
SELECT COALESCE(delay_reason_std, '(표준 사유 없음)') AS delay_reason_std,
       is_reason_operational_outcome,
       GROUP_CONCAT(DISTINCT delay_reason_raw ORDER BY delay_reason_raw SEPARATOR ' | ') AS raw_reason_values,
       COUNT(*) AS reason_rows,
       SUM(status_raw = '지연') AS delayed_status_rows,
       SUM(status_raw = '출발') AS departed_status_rows,
       SUM(status_raw = '취소') AS cancelled_status_rows,
       SUM(status_raw = '회항') AS diverted_status_rows,
       SUM(status_raw IS NULL) AS status_unknown_rows
FROM v_flight_analysis
WHERE is_passenger
  AND is_international = TRUE
  AND delay_reason_raw IS NOT NULL
  AND TRIM(delay_reason_raw) <> ''
GROUP BY COALESCE(delay_reason_std, '(표준 사유 없음)'), is_reason_operational_outcome
ORDER BY reason_rows DESC, delay_reason_std;

-- name: diversion_status_reason_crosscheck
-- 상태값 회항과 지연원인 회항의 교집합·차이를 여객편에서 다시 확인한다.
SELECT airport_name_raw,
       COALESCE(status_raw, '(NULL)') AS status_raw,
       COALESCE(delay_reason_raw, '(NULL)') AS delay_reason_raw,
       COUNT(*) AS flight_rows
FROM v_flight_analysis
WHERE is_passenger
  AND is_international = TRUE
  AND (status_raw = '회항' OR delay_reason_raw = '회항')
GROUP BY airport_name_raw,
         COALESCE(status_raw, '(NULL)'),
         COALESCE(delay_reason_raw, '(NULL)')
ORDER BY flight_rows DESC, airport_name_raw, status_raw, delay_reason_raw;
