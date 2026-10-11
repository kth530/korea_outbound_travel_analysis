-- 목적지별 여객 규모·최근 증가 인원·계절성을 비교한다.

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


-- name: demand_metric_monthly_total_check
WITH market AS (
    SELECT period_ym, SUM(passengers) AS passengers FROM v_route_monthly
    WHERE is_international=TRUE AND period_ym IS NOT NULL GROUP BY period_ym
), destination AS (
    SELECT period_ym, SUM(passengers) AS passengers FROM v_metric_demand_destination_monthly
    GROUP BY period_ym
)
SELECT COUNT(*) AS checked_months,
       SUM(ABS(m.passengers-d.passengers)) AS passenger_absolute_difference,
       MAX(ABS(m.passengers-d.passengers)) AS passenger_max_month_difference
FROM market AS m JOIN destination AS d USING (period_ym);

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

