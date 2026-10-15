-- 05 수요 예측용 정적 읽기 인터페이스와 검산 쿼리.
-- 목적지×월 패널과 프로필은 Python ETL에서 완성해 테이블에 적재한다.
-- 기준월 의존 피처·타깃·성장계수는 scripts/feature_layer.py가 생성한다.

-- name: create_v_model_destination_monthly_all
-- 목적지 수요 예측의 공통 월 패널 원천.
CREATE OR REPLACE VIEW v_model_destination_monthly_all AS
SELECT period_ym, destination_canonical_std, passengers, operations,
       origin_airport_count
FROM etl_destination_monthly_all;

-- name: create_v_demand_destination_profile
-- 목적지 1행. 표본 규칙과 계절형 라벨은 ETL 테이블에서 읽는다.
-- 예측 피처로 쓰는 계절지수는 별도(노트북, as-of-origin).
CREATE OR REPLACE VIEW v_demand_destination_profile AS
SELECT destination_canonical_std, first_period, last_period,
       months_present, months_positive, months_2023, months_2024,
       months_2025, months_2026, total_passengers,
       q1_2024, q2_2024, q1_2025, q2_2025,
       sample_band, in_modeling_universe,
       seasonal_label_2024, seasonal_label_2025
FROM etl_destination_profile;

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
-- 목적지×월 결합 뷰의 행·기간·합계 정합성 서명.
SELECT COUNT(*)                                   AS rows_,
       COUNT(DISTINCT destination_canonical_std)  AS destinations,
       MIN(period_ym)                             AS min_period,
       MAX(period_ym)                             AS max_period,
       CAST(SUM(passengers) AS SIGNED)            AS sum_passengers,
       CAST(SUM(operations) AS SIGNED)            AS sum_operations,
       SUM(origin_airport_count)                  AS sum_origin_airport_count
FROM v_model_destination_monthly_all;
