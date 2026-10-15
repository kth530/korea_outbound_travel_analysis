-- Python ETL 결과를 제공하는 분석용 읽기 뷰.
-- 국제선 범위·공항명·월 키·목적지 합계를 여기에서 다시 계산하지 않는다.

-- name: create_v_domestic_airport_reference
CREATE OR REPLACE VIEW v_domestic_airport_reference AS
SELECT destination_std, airport_canonical_std, airport_code, reference_source
FROM etl_domestic_airport_reference;

-- name: create_v_route_monthly
CREATE OR REPLACE VIEW v_route_monthly AS
SELECT origin_airport_raw, destination_airport_raw, period_raw, period_ym,
       passengers, operations, origin_airport_std, destination_airport_std,
       route_scope_std, is_international
FROM etl_route_monthly_2023_2025;

-- name: create_v_route_monthly_2026
CREATE OR REPLACE VIEW v_route_monthly_2026 AS
SELECT origin_airport_raw, destination_airport_raw, period_raw, period_ym,
       passengers, operations, origin_airport_std, destination_airport_std,
       route_scope_std, is_international
FROM etl_route_monthly_2026;
