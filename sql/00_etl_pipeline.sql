-- Python ETL에서 검산·표준화·국제선 판별·집계를 마친 분석 테이블.
-- 원천 Excel은 data/raw와 data/raw_2026에 그대로 보관한다.
CREATE TABLE IF NOT EXISTS etl_domestic_airport_reference (
    destination_std VARCHAR(100) NOT NULL PRIMARY KEY,
    airport_canonical_std VARCHAR(100) NOT NULL,
    airport_code CHAR(3) NOT NULL,
    reference_source VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS etl_route_monthly_2023_2025 (
    origin_airport_raw VARCHAR(100) NOT NULL,
    destination_airport_raw VARCHAR(100) NOT NULL,
    period_raw VARCHAR(20) NOT NULL,
    period_ym CHAR(6) NOT NULL,
    passengers BIGINT NULL,
    operations BIGINT NULL,
    origin_airport_std VARCHAR(100) NULL,
    destination_airport_std VARCHAR(100) NULL,
    route_scope_std VARCHAR(20) NOT NULL,
    is_international TINYINT NULL,
    PRIMARY KEY (origin_airport_raw, destination_airport_raw, period_raw)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS etl_route_monthly_2026 LIKE etl_route_monthly_2023_2025;

CREATE TABLE IF NOT EXISTS etl_destination_monthly_all (
    period_ym CHAR(6) NOT NULL,
    destination_canonical_std VARCHAR(100) NOT NULL,
    passengers BIGINT NOT NULL,
    operations BIGINT NOT NULL,
    origin_airport_count INT NOT NULL,
    PRIMARY KEY (period_ym, destination_canonical_std)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS etl_destination_profile (
    destination_canonical_std VARCHAR(100) NOT NULL PRIMARY KEY,
    first_period CHAR(6) NOT NULL,
    last_period CHAR(6) NOT NULL,
    months_present INT NOT NULL,
    months_positive INT NOT NULL,
    months_2023 INT NOT NULL,
    months_2024 INT NOT NULL,
    months_2025 INT NOT NULL,
    months_2026 INT NOT NULL,
    total_passengers BIGINT NOT NULL,
    q1_2024 BIGINT NULL,
    q2_2024 BIGINT NULL,
    q1_2025 BIGINT NULL,
    q2_2025 BIGINT NULL,
    sample_band VARCHAR(10) NOT NULL,
    in_modeling_universe TINYINT NOT NULL,
    seasonal_label_2024 VARCHAR(10) NULL,
    seasonal_label_2025 VARCHAR(10) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
