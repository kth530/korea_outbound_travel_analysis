-- 시장 월별 추이와 연도 내 월평균 대비 계절 패턴.

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
