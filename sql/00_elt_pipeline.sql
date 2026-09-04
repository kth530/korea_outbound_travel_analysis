-- 분석용 raw 테이블에는 원본 업무 컬럼만 보관한다.
-- 파일·배치 적재 이력은 meta_load_* 테이블로 분리한다.

CREATE TABLE IF NOT EXISTS meta_load_batch (
    batch_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pipeline_name VARCHAR(100) NOT NULL,
    source_root VARCHAR(500) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    status VARCHAR(20) NOT NULL,
    note TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS meta_load_file (
    source_file VARCHAR(500) NOT NULL,
    target_table VARCHAR(100) NOT NULL,
    source_sha256 CHAR(64) NOT NULL,
    source_year SMALLINT UNSIGNED NULL,
    source_month TINYINT UNSIGNED NULL,
    source_rows INT UNSIGNED NOT NULL,
    loaded_rows INT UNSIGNED NOT NULL,
    batch_id BIGINT UNSIGNED NOT NULL,
    status VARCHAR(20) NOT NULL,
    loaded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (source_file, target_table),
    CONSTRAINT fk_meta_load_file_batch
        FOREIGN KEY (batch_id) REFERENCES meta_load_batch(batch_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS raw_route_passenger (
    origin_airport_raw VARCHAR(100) NOT NULL,
    destination_airport_raw VARCHAR(100) NULL,
    period_raw VARCHAR(20) NOT NULL,
    passengers BIGINT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS raw_route_operations (
    origin_airport_raw VARCHAR(100) NOT NULL,
    destination_airport_raw VARCHAR(100) NULL,
    period_raw VARCHAR(20) NOT NULL,
    operations BIGINT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS raw_airline_passenger (
    airline_name_raw VARCHAR(150) NOT NULL,
    period_raw VARCHAR(20) NOT NULL,
    passengers BIGINT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS raw_airline_operations (
    airline_name_raw VARCHAR(150) NOT NULL,
    period_raw VARCHAR(20) NOT NULL,
    operations BIGINT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS raw_airport_passenger (
    airport_name_raw VARCHAR(100) NOT NULL,
    period_raw VARCHAR(20) NOT NULL,
    passengers BIGINT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS raw_country_passenger (
    region_raw VARCHAR(100) NOT NULL,
    country_raw VARCHAR(100) NULL,
    period_raw VARCHAR(20) NOT NULL,
    passengers BIGINT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS raw_departure_flight (
    direction_raw VARCHAR(20) NULL,
    airport_name_raw VARCHAR(100) NULL,
    airline_name_raw VARCHAR(150) NULL,
    flight_number_raw VARCHAR(30) NULL,
    destination_raw VARCHAR(150) NULL,
    flight_date_raw VARCHAR(20) NULL,
    scheduled_time_raw VARCHAR(30) NULL,
    estimated_time_raw VARCHAR(30) NULL,
    actual_departure_time_raw VARCHAR(30) NULL,
    service_type_raw VARCHAR(30) NULL,
    status_raw VARCHAR(30) NULL,
    delay_reason_raw VARCHAR(200) NULL,
    INDEX idx_raw_departure_flight_date (flight_date_raw),
    INDEX idx_raw_departure_flight_airport (airport_name_raw),
    INDEX idx_raw_departure_flight_airline (airline_name_raw)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE OR REPLACE VIEW vw_meta_load_status AS
SELECT
    f.target_table,
    f.source_year,
    f.source_month,
    COUNT(*) AS source_file_count,
    SUM(f.source_rows) AS source_rows,
    SUM(f.loaded_rows) AS loaded_rows,
    MAX(f.loaded_at) AS last_loaded_at
FROM meta_load_file AS f
WHERE f.status = 'loaded'
GROUP BY f.target_table, f.source_year, f.source_month;
