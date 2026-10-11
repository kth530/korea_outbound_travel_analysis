-- 목적지×월 분석의 원본 노선 통계와 적재 이력. 다른 집계·편별 로그는 모델 입력에 쓰지 않는다.
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
    CONSTRAINT fk_meta_load_file_batch FOREIGN KEY (batch_id) REFERENCES meta_load_batch(batch_id)
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
