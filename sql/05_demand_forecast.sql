-- 05 수요 예측용 정적 뷰.
-- 이 파일은 origin과 무관한 집계만 만든다. 시점 의존(origin별) 피처·계절지수·타깃·성장계수는
-- 노트북(pandas)에서 as-of-origin 규율로 생성한다. 여기서는 만들지 않는다.
-- 상류 뷰(v_route_monthly=02, v_route_monthly_2026=2026 홀드아웃 파이프라인)는 수정하지 않고 참조만 한다.

-- name: create_v_model_destination_monthly_all
-- 목적지 수요 예측의 공통 월 패널 원천. 2023~2025와 2026을 동일 집계 단위로 결합한다.
-- 기존 홀드아웃 파이프라인(archive)에 있던 정의를 로직 변경 없이 05로 이관한다(멱등).
CREATE OR REPLACE VIEW v_model_destination_monthly_all AS
SELECT period_ym,
       destination_airport_std AS destination_canonical_std,
       SUM(COALESCE(passengers, 0)) AS passengers,
       SUM(COALESCE(operations, 0)) AS operations,
       COUNT(DISTINCT CASE WHEN COALESCE(passengers, 0) > 0 OR COALESCE(operations, 0) > 0 THEN origin_airport_std END) AS origin_airport_count
FROM (
    SELECT period_ym, origin_airport_std, destination_airport_std, passengers, operations
    FROM v_route_monthly
    WHERE is_international = TRUE AND period_ym IS NOT NULL
    UNION ALL
    SELECT period_ym, origin_airport_std, destination_airport_std, passengers, operations
    FROM v_route_monthly_2026
    WHERE is_international = TRUE AND period_ym IS NOT NULL
) AS combined
GROUP BY period_ym, destination_airport_std;

-- name: create_v_demand_destination_profile
-- 목적지 1행. 표본 규칙(관측 개월 수)과 계절형 정적 라벨(2024/2025)을 만든다.
-- 계절형 라벨은 보고·세그먼트용 정적 속성이다. 예측 피처로 쓰는 계절지수는 별도(노트북, as-of-origin).
CREATE OR REPLACE VIEW v_demand_destination_profile AS
WITH base AS (
    SELECT destination_canonical_std,
           period_ym,
           passengers,
           LEFT(period_ym, 4)  AS yr,
           RIGHT(period_ym, 2) AS mo
    FROM v_model_destination_monthly_all
), agg AS (
    SELECT destination_canonical_std,
           MIN(period_ym) AS first_period,
           MAX(period_ym) AS last_period,
           COUNT(*)                 AS months_present,
           SUM(passengers > 0)      AS months_positive,
           SUM(yr = '2023')         AS months_2023,
           SUM(yr = '2024')         AS months_2024,
           SUM(yr = '2025')         AS months_2025,
           SUM(yr = '2026')         AS months_2026,
           SUM(passengers)          AS total_passengers,
           SUM(CASE WHEN yr = '2024' AND mo IN ('01','02','03') THEN passengers END) AS q1_2024,
           SUM(CASE WHEN yr = '2024' AND mo IN ('04','05','06') THEN passengers END) AS q2_2024,
           SUM(CASE WHEN yr = '2025' AND mo IN ('01','02','03') THEN passengers END) AS q1_2025,
           SUM(CASE WHEN yr = '2025' AND mo IN ('04','05','06') THEN passengers END) AS q2_2025
    FROM base
    GROUP BY destination_canonical_std
)
SELECT agg.*,
       CASE WHEN months_present >= 36 THEN 'ge36'
            WHEN months_present >= 24 THEN '24_35'
            WHEN months_present >= 12 THEN '12_23'
            ELSE 'lt12' END AS sample_band,
       (months_present >= 24) AS in_modeling_universe,
       CASE WHEN q1_2024 IS NULL OR q2_2024 IS NULL THEN NULL
            WHEN q1_2024 > q2_2024 * 1.05 THEN 'winter'
            WHEN q2_2024 > q1_2024 * 1.05 THEN 'summer'
            ELSE 'flat' END AS seasonal_label_2024,
       CASE WHEN q1_2025 IS NULL OR q2_2025 IS NULL THEN NULL
            WHEN q1_2025 > q2_2025 * 1.05 THEN 'winter'
            WHEN q2_2025 > q1_2025 * 1.05 THEN 'summer'
            ELSE 'flat' END AS seasonal_label_2025
FROM agg;

-- name: profile_sample_bands
-- 표본 밴드별 목적지 수와 여객 비중.
SELECT sample_band,
       COUNT(*)              AS destinations,
       SUM(total_passengers) AS passengers,
       ROUND(100.0 * SUM(total_passengers) / SUM(SUM(total_passengers)) OVER (), 1) AS passenger_share_pct
FROM v_demand_destination_profile
GROUP BY sample_band
ORDER BY FIELD(sample_band, 'ge36', '24_35', '12_23', 'lt12');

-- name: seasonal_label_agreement
-- 2024 기준 라벨과 2025 기준 라벨의 목적지별 일치율. 전체와 모델링 유니버스(>=24개월) 각각.
SELECT scope_label,
       comparable,
       same,
       ROUND(100.0 * same / NULLIF(comparable, 0), 1) AS agreement_pct
FROM (
    SELECT 'all' AS scope_label,
           SUM(seasonal_label_2024 IS NOT NULL AND seasonal_label_2025 IS NOT NULL) AS comparable,
           SUM(seasonal_label_2024 IS NOT NULL AND seasonal_label_2025 IS NOT NULL
               AND seasonal_label_2024 = seasonal_label_2025) AS same
    FROM v_demand_destination_profile
    UNION ALL
    SELECT 'modeling_universe',
           SUM(seasonal_label_2024 IS NOT NULL AND seasonal_label_2025 IS NOT NULL),
           SUM(seasonal_label_2024 IS NOT NULL AND seasonal_label_2025 IS NOT NULL
               AND seasonal_label_2024 = seasonal_label_2025)
    FROM v_demand_destination_profile
    WHERE in_modeling_universe = 1
) AS a;

-- name: seasonal_label_transition
-- 2024 -> 2025 라벨 전이 교차표(불안정성 진단).
SELECT COALESCE(seasonal_label_2024, 'null') AS label_2024,
       COALESCE(seasonal_label_2025, 'null') AS label_2025,
       COUNT(*) AS destinations
FROM v_demand_destination_profile
WHERE in_modeling_universe = 1
GROUP BY seasonal_label_2024, seasonal_label_2025
ORDER BY label_2024, label_2025;

-- name: model_view_parity_signature
-- 이관 전후 대조용 서명. 이관 DDL이 기존 뷰와 동일 결과인지 확인한다.
SELECT COUNT(*)                                   AS rows_,
       COUNT(DISTINCT destination_canonical_std)  AS destinations,
       MIN(period_ym)                             AS min_period,
       MAX(period_ym)                             AS max_period,
       CAST(SUM(passengers) AS SIGNED)            AS sum_passengers,
       CAST(SUM(operations) AS SIGNED)            AS sum_operations,
       SUM(origin_airport_count)                  AS sum_origin_airport_count
FROM v_model_destination_monthly_all;
