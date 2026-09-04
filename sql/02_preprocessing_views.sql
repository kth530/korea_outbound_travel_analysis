-- name: create_v_domestic_airport_reference
-- 한국공항공사 공항 목록(https://www.airport.co.kr/booking/ajaxf/frTrafficGoodsSvc/getAvailAirportList.do)과
-- 인천국제공항공사(https://www.airport.kr/ap_ko/index.do)를 기준으로 만든 국내 공항 참조 뷰다.
-- 원문 집계에 실제로 등장한 공항만 쓰지 않아, 국제선 실적이 없는 국내 공항도 포함한다.
CREATE OR REPLACE VIEW v_domestic_airport_reference AS
SELECT '김포' AS destination_std, '김포' AS airport_canonical_std, 'GMP' AS airport_code,
       'KAC official airport list' AS reference_source
UNION ALL SELECT '김해', '김해', 'PUS', 'KAC official airport list'
UNION ALL SELECT '대구', '대구', 'TAE', 'KAC official airport list'
UNION ALL SELECT '무안', '무안', 'MWX', 'KAC official airport list'
UNION ALL SELECT '양양', '양양', 'YNY', 'KAC official airport list'
UNION ALL SELECT '울산', '울산', 'USN', 'KAC official airport list'
UNION ALL SELECT '인천', '인천', 'ICN', 'IIAC official airport list'
UNION ALL SELECT '제주', '제주', 'CJU', 'KAC official airport list'
UNION ALL SELECT '청주', '청주', 'CJJ', 'KAC official airport list'
UNION ALL SELECT '광주', '광주', 'KWJ', 'KAC official airport list'
UNION ALL SELECT '여수', '여수', 'RSU', 'KAC official airport list'
UNION ALL SELECT '포항경주', '포항경주', 'KPO', 'KAC official airport list'
UNION ALL SELECT '사천', '사천', 'HIN', 'KAC official airport list'
UNION ALL SELECT '군산', '군산', 'KUV', 'KAC official airport list'
UNION ALL SELECT '원주', '원주', 'WJU', 'KAC official airport list';

-- name: create_v_destination_alias_reference
-- 출발 로그와 노선 집계의 명칭 차이를 별도 참조로 보존한다.
-- 원문 목적지와 destination_std는 바꾸지 않고, 검토된 국제선 별칭만 canonical 값에 연결한다.
CREATE OR REPLACE VIEW v_destination_alias_reference AS
SELECT '수안나폼' AS destination_std, '방콕' AS destination_canonical_std, 'international' AS scope_std, 'reviewed_log_to_route_alias' AS reference_source
UNION ALL SELECT '하네다', '도쿄하네다', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '타오위안', '타이페이', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '깜라인', '나트랑캄란', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '싱가포르', '싱가폴', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '떤선녓', '호치민', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '베이징', '북경', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '노이바이', '하노이', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '삿포로', '삿보로', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '오키나와', '오끼나와', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '푸꾸옥', '푸쿡', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '칭기즈칸국제공항', '울란바토르', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '가오슝', '카오슝', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '상해홍차우', '홍차오', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '선전', '센젠', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '팡라로', '타크빌라란', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '뉴욕', '뉴욕JFK', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '클라크', '클라크필드', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '파리', '파리샤를드골', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '베이징다싱', '다싱', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '남경', '난징', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '항저우', '항조우', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '프놈펜', '프롬펜', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '애틀랜타', '아틀란타', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '밴쿠버', '뱅쿠버', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '위해', '웨이하이', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '푸껫', '푸켓', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '타슈켄트', '타쉬켄트', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '송산', '쑹산', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '댈러스', '달라스', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '로마', '로마파우미치노', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '청두티안푸', '텐푸', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '암스테르담', '암스텔담', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '샤먼가오치', '샤먼', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '알마티', '알마아타', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '다카마쓰', '다가마스', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '구마모토', '구마모도', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '마쓰야마', '마즈야마', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '아부다비', '자이드', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '타이중', '따이쭝', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '수난슈오팡', '우시샤우팡', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '미니애폴리스', '미네아폴리스', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '워싱톤', '워싱턴덜레스', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '보스턴', '보스톤', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '충칭', '총킹', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '브리즈번', '브리스번', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '기타규슈', '키타큐슈', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '라스베이거스', '라스베가스', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '가고시마', '카고시마', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '양곤', '랑군', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '푸저우', '푸조우', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '돈므앙', '돈무앙', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '뉴어크리버티', '뉴왁', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '오이타', '오이다', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '카트만두', '카투만두', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '멕시코시티', '멕시코', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '반다르스리', '반다르세리베가완', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '미야자키', '미와사키', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '목단강', '무단지앙', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '오카야마', '오까야마', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '니가타', '니이가타', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '반다라나이케', '콜롬보', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '고마쓰', '고마스', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '석가장', '쉬지아쭈앙', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '허페이', '허폐', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '옌청', '염성', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '양저우', '양저우타이저우', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '킹칼리드', '리야드', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '아사히카와', '아사이까와', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '가목사', '자무쓰', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '하코다테', '하꼬다데', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '멜버른', '멜버른툴라마린', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '코페르니쿠스공항브로츠와프', '브로츠와프', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '태원', '타이유안', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '아시가바트', '아쉬가바트', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '우이산', '우이산공항', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '위린위양', '위린', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '엔스쉬자핑', '엔시쉬자핑', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '꾸이양', '구이양', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '화롄', '화리엔', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '케언스', '캐언스', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '마르세유', '마르세이유프로방스', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '시안무당산', '우당산', 'international', 'reviewed_log_to_route_alias'
UNION ALL SELECT '퀘벡장르사주', '퀴백', 'international', 'reviewed_log_to_route_alias';

-- name: create_v_route_monthly
-- 노선 여객·운항 통계를 NULL-safe 전체 조인하고, 국내선 형태 예외 행을 삭제하지 않은 채 범위를 표시한다.
CREATE OR REPLACE VIEW v_route_monthly AS
WITH passenger_rows AS (
    SELECT origin_airport_raw, destination_airport_raw, period_raw, passengers, 1 AS passenger_exists
    FROM raw_route_passenger
    WHERE origin_airport_raw <> '전체 합계'
), operation_rows AS (
    SELECT origin_airport_raw, destination_airport_raw, period_raw, operations
    FROM raw_route_operations
    WHERE origin_airport_raw <> '전체 합계'
), combined AS (
    SELECT p.origin_airport_raw, p.destination_airport_raw, p.period_raw,
           CASE
               WHEN TRIM(p.period_raw) REGEXP '^[0-9]{4}년[[:space:]]*[0-9]{1,2}월$'
                AND CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(p.period_raw), '년', -1), '월', 1)) AS UNSIGNED)
                    BETWEEN 1 AND 12
               THEN CONCAT(LEFT(TRIM(p.period_raw), 4), LPAD(CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(p.period_raw), '년', -1), '월', 1)) AS UNSIGNED), 2, '0'))
           END AS period_ym,
           p.passengers, o.operations
    FROM passenger_rows AS p
    LEFT JOIN operation_rows AS o
      ON p.origin_airport_raw <=> o.origin_airport_raw
     AND p.destination_airport_raw <=> o.destination_airport_raw
     AND p.period_raw <=> o.period_raw
    UNION ALL
    SELECT o.origin_airport_raw, o.destination_airport_raw, o.period_raw,
           CASE
               WHEN TRIM(o.period_raw) REGEXP '^[0-9]{4}년[[:space:]]*[0-9]{1,2}월$'
                AND CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(o.period_raw), '년', -1), '월', 1)) AS UNSIGNED)
                    BETWEEN 1 AND 12
               THEN CONCAT(LEFT(TRIM(o.period_raw), 4), LPAD(CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(o.period_raw), '년', -1), '월', 1)) AS UNSIGNED), 2, '0'))
           END,
           p.passengers, o.operations
    FROM operation_rows AS o
    LEFT JOIN passenger_rows AS p
      ON p.origin_airport_raw <=> o.origin_airport_raw
     AND p.destination_airport_raw <=> o.destination_airport_raw
     AND p.period_raw <=> o.period_raw
    WHERE p.passenger_exists IS NULL
), standardized AS (
    SELECT c.*,
           NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(c.origin_airport_raw), '\\([^)]*\\)', ''), '[[:space:]/_-]', ''), '') AS origin_airport_std,
           NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(c.destination_airport_raw), '\\([^)]*\\)', ''), '[[:space:]/_-]', ''), '') AS destination_airport_std
    FROM combined AS c
), scoped AS (
    SELECT s.*,
           CASE
               WHEN s.origin_airport_std IS NULL OR s.destination_airport_std IS NULL THEN 'unresolved'
               WHEN o.destination_std IS NOT NULL AND d.destination_std IS NOT NULL THEN 'domestic'
               WHEN o.destination_std IS NOT NULL AND d.destination_std IS NULL THEN 'international'
               ELSE 'unresolved'
           END AS route_scope_std
    FROM standardized AS s
    LEFT JOIN v_domestic_airport_reference AS o ON s.origin_airport_std = o.destination_std
    LEFT JOIN v_domestic_airport_reference AS d ON s.destination_airport_std = d.destination_std
)
SELECT scoped.*,
       CASE route_scope_std
           WHEN 'international' THEN TRUE
           WHEN 'domestic' THEN FALSE
           ELSE NULL
       END AS is_international
FROM scoped;

-- name: create_v_international_destination_reference
-- 국내선 형태 예외를 제외한 양수 여객 노선 목적지로 국제선 참조 목록을 만든다.
CREATE OR REPLACE VIEW v_international_destination_reference AS
SELECT destination_airport_std AS destination_canonical_std,
       GROUP_CONCAT(DISTINCT destination_airport_raw ORDER BY destination_airport_raw SEPARATOR ' | ') AS route_destination_raw_values,
       COUNT(DISTINCT destination_airport_raw) AS route_destination_raw_count,
       'v_route_monthly: international and passengers > 0' AS reference_source
FROM v_route_monthly
WHERE is_international = TRUE
  AND passengers > 0
GROUP BY destination_airport_std;

-- name: create_v_flight_analysis
-- 출발 로그의 시간 파싱·비파괴 표준화·국내·국제 참조 근거를 한 곳에 둔 읽기 전용 분석 뷰다.
CREATE OR REPLACE VIEW v_flight_analysis AS
WITH time_and_text AS (
    SELECT
        r.*,
        CASE
            WHEN TRIM(flight_date_raw) REGEXP '^[0-9]{8}$'
             AND STR_TO_DATE(TRIM(flight_date_raw), '%Y%m%d') IS NOT NULL
            THEN TRUE ELSE FALSE
        END AS is_flight_date_valid,
        CASE
            WHEN TRIM(scheduled_time_raw) REGEXP '^[0-9]{1,2}:[0-9]{2}$'
             AND CAST(SUBSTRING_INDEX(TRIM(scheduled_time_raw), ':', 1) AS UNSIGNED) BETWEEN 0 AND 23
             AND CAST(SUBSTRING_INDEX(TRIM(scheduled_time_raw), ':', -1) AS UNSIGNED) BETWEEN 0 AND 59
            THEN TRUE ELSE FALSE
        END AS is_scheduled_valid,
        CASE
            WHEN TRIM(estimated_time_raw) REGEXP '^[0-9]{1,2}:[0-9]{2}$'
             AND CAST(SUBSTRING_INDEX(TRIM(estimated_time_raw), ':', 1) AS UNSIGNED) BETWEEN 0 AND 23
             AND CAST(SUBSTRING_INDEX(TRIM(estimated_time_raw), ':', -1) AS UNSIGNED) BETWEEN 0 AND 59
            THEN TRUE ELSE FALSE
        END AS is_estimated_valid,
        CASE
            WHEN TRIM(actual_departure_time_raw) REGEXP '^[0-9]{1,2}:[0-9]{2}$'
             AND CAST(SUBSTRING_INDEX(TRIM(actual_departure_time_raw), ':', 1) AS UNSIGNED) BETWEEN 0 AND 23
             AND CAST(SUBSTRING_INDEX(TRIM(actual_departure_time_raw), ':', -1) AS UNSIGNED) BETWEEN 0 AND 59
            THEN TRUE ELSE FALSE
        END AS is_actual_valid,
        NULLIF(REGEXP_REPLACE(UPPER(TRIM(flight_number_raw)), '[[:space:]]+', ''), '') AS flight_number_std,
        TRIM(airline_name_raw) AS airline_std,
        NULLIF(
            REGEXP_REPLACE(
                REGEXP_REPLACE(TRIM(destination_raw), '\\([^)]*\\)', ''),
                '[[:space:]/_-]',
                ''
            ),
            ''
        ) AS destination_std
    FROM raw_departure_flight AS r
), time_minutes AS (
    SELECT
        time_and_text.*,
        CASE WHEN is_scheduled_valid THEN
            CAST(SUBSTRING_INDEX(TRIM(scheduled_time_raw), ':', 1) AS UNSIGNED) * 60
            + CAST(SUBSTRING_INDEX(TRIM(scheduled_time_raw), ':', -1) AS UNSIGNED)
        END AS scheduled_minutes,
        CASE WHEN is_estimated_valid THEN
            CAST(SUBSTRING_INDEX(TRIM(estimated_time_raw), ':', 1) AS UNSIGNED) * 60
            + CAST(SUBSTRING_INDEX(TRIM(estimated_time_raw), ':', -1) AS UNSIGNED)
        END AS estimated_minutes,
        CASE WHEN is_actual_valid THEN
            CAST(SUBSTRING_INDEX(TRIM(actual_departure_time_raw), ':', 1) AS UNSIGNED) * 60
            + CAST(SUBSTRING_INDEX(TRIM(actual_departure_time_raw), ':', -1) AS UNSIGNED)
        END AS actual_minutes
    FROM time_and_text
), destination_resolved AS (
    SELECT t.*,
           COALESCE(a.destination_canonical_std, t.destination_std) AS destination_canonical_std,
           a.reference_source AS destination_alias_reference_source
    FROM time_minutes AS t
    LEFT JOIN v_destination_alias_reference AS a
      ON t.destination_std = a.destination_std
), reference_joined AS (
    SELECT d.*,
           domestic.destination_std AS domestic_reference_destination_std,
           domestic.reference_source AS domestic_reference_source,
           international.destination_canonical_std AS international_reference_destination_std,
           international.reference_source AS international_reference_source
    FROM destination_resolved AS d
    LEFT JOIN v_domestic_airport_reference AS domestic
      ON d.destination_canonical_std = domestic.destination_std
    LEFT JOIN v_international_destination_reference AS international
      ON d.destination_canonical_std = international.destination_canonical_std
), scope_classified AS (
    SELECT r.*,
           CASE
               WHEN r.destination_canonical_std IS NULL THEN 'unresolved'
               WHEN r.domestic_reference_destination_std IS NOT NULL
                AND r.international_reference_destination_std IS NOT NULL THEN 'reference_conflict'
               WHEN r.domestic_reference_destination_std IS NOT NULL THEN 'domestic'
               WHEN r.international_reference_destination_std IS NOT NULL THEN 'international'
               ELSE 'unresolved'
           END AS flight_scope_std
    FROM reference_joined AS r
)
SELECT
    s.*,
    CASE WHEN s.is_flight_date_valid
         THEN STR_TO_DATE(TRIM(s.flight_date_raw), '%Y%m%d')
    END AS flight_date,
    CASE WHEN s.is_flight_date_valid
         THEN LEFT(TRIM(s.flight_date_raw), 6)
    END AS operating_month,
    s.is_scheduled_valid AND s.is_actual_valid AS is_time_calculable,
    CASE WHEN s.is_scheduled_valid AND s.is_actual_valid
         THEN CAST(s.actual_minutes AS SIGNED) - CAST(s.scheduled_minutes AS SIGNED)
    END AS raw_gap_minutes,
    CASE WHEN s.is_scheduled_valid AND s.is_estimated_valid
         THEN CAST(s.estimated_minutes AS SIGNED) - CAST(s.scheduled_minutes AS SIGNED)
    END AS est_gap_minutes,
    CASE WHEN s.service_type_raw = '여객' THEN TRUE ELSE FALSE END AS is_passenger,
    CASE WHEN s.status_raw IN ('출발', '지연') THEN TRUE ELSE FALSE END AS is_denominator,
    CASE WHEN s.status_raw = '취소' THEN TRUE ELSE FALSE END AS is_cancelled,
    CASE WHEN s.status_raw = '회항' THEN TRUE ELSE FALSE END AS is_diverted,
    CASE WHEN s.status_raw IS NULL THEN TRUE ELSE FALSE END AS is_status_unknown,
    CASE WHEN s.is_scheduled_valid
         THEN CAST(SUBSTRING_INDEX(TRIM(s.scheduled_time_raw), ':', 1) AS UNSIGNED)
    END AS scheduled_hour,
    CASE WHEN s.delay_reason_raw = '회항' THEN TRUE ELSE FALSE END AS is_reason_operational_outcome,
    CASE
        WHEN s.delay_reason_raw = '회항' THEN NULL
        WHEN s.delay_reason_raw = '연결-항공기' THEN '항공기 연결에 의한 지연'
        ELSE s.delay_reason_raw
    END AS delay_reason_std,
    CASE
        WHEN s.destination_canonical_std IS NULL THEN NULL
        WHEN s.domestic_reference_destination_std IS NOT NULL THEN TRUE
        ELSE FALSE
    END AS is_domestic_reference_match,
    CASE
        WHEN s.destination_canonical_std IS NULL THEN NULL
        WHEN s.international_reference_destination_std IS NOT NULL THEN TRUE
        ELSE FALSE
    END AS is_international_reference_match,
    CASE s.flight_scope_std
        WHEN 'international' THEN TRUE
        WHEN 'domestic' THEN FALSE
        ELSE NULL
    END AS is_international,
    CASE
        WHEN s.flight_scope_std = 'unresolved' AND s.destination_canonical_std IS NULL THEN 'blank_destination'
        WHEN s.flight_scope_std = 'reference_conflict' THEN 'domestic_and_international_reference'
        WHEN s.flight_scope_std = 'domestic' THEN s.domestic_reference_source
        WHEN s.flight_scope_std = 'international' AND s.destination_alias_reference_source IS NOT NULL
            THEN CONCAT(s.destination_alias_reference_source, ' + ', s.international_reference_source)
        WHEN s.flight_scope_std = 'international' THEN s.international_reference_source
        ELSE 'no_reference_match'
    END AS scope_reference_source
FROM scope_classified AS s;

-- name: create_v_departure_flight_compatibility
-- 기존 03 이상 쿼리의 v_departure_flight 참조를 끊지 않는 호환 별칭이다.
CREATE OR REPLACE VIEW v_departure_flight AS
SELECT * FROM v_flight_analysis;

-- name: create_v_airline_monthly
CREATE OR REPLACE VIEW v_airline_monthly AS
WITH passenger_rows AS (
    SELECT airline_name_raw, period_raw, passengers, 1 AS passenger_exists
    FROM raw_airline_passenger
    WHERE airline_name_raw NOT IN ('국적사 계', '외항사 계', '전체 합계')
), operation_rows AS (
    SELECT airline_name_raw, period_raw, operations
    FROM raw_airline_operations
    WHERE airline_name_raw NOT IN ('국적사 계', '외항사 계', '전체 합계')
)
SELECT p.airline_name_raw, p.period_raw,
       CASE
           WHEN TRIM(p.period_raw) REGEXP '^[0-9]{4}년[[:space:]]*[0-9]{1,2}월$'
            AND CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(p.period_raw), '년', -1), '월', 1)) AS UNSIGNED)
                BETWEEN 1 AND 12
           THEN CONCAT(
               LEFT(TRIM(p.period_raw), 4),
               LPAD(CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(p.period_raw), '년', -1), '월', 1)) AS UNSIGNED), 2, '0')
           )
       END AS period_ym,
       p.passengers, o.operations
FROM passenger_rows AS p
LEFT JOIN operation_rows AS o
  ON p.airline_name_raw <=> o.airline_name_raw
 AND p.period_raw <=> o.period_raw
UNION ALL
SELECT o.airline_name_raw, o.period_raw,
       CASE
           WHEN TRIM(o.period_raw) REGEXP '^[0-9]{4}년[[:space:]]*[0-9]{1,2}월$'
            AND CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(o.period_raw), '년', -1), '월', 1)) AS UNSIGNED)
                BETWEEN 1 AND 12
           THEN CONCAT(
               LEFT(TRIM(o.period_raw), 4),
               LPAD(CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(o.period_raw), '년', -1), '월', 1)) AS UNSIGNED), 2, '0')
           )
       END AS period_ym,
       p.passengers, o.operations
FROM operation_rows AS o
LEFT JOIN passenger_rows AS p
  ON p.airline_name_raw <=> o.airline_name_raw
 AND p.period_raw <=> o.period_raw
WHERE p.passenger_exists IS NULL;

-- name: create_v_airport_monthly
CREATE OR REPLACE VIEW v_airport_monthly AS
SELECT airport_name_raw, period_raw,
       CASE
           WHEN TRIM(period_raw) REGEXP '^[0-9]{4}년[[:space:]]*[0-9]{1,2}월$'
            AND CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(period_raw), '년', -1), '월', 1)) AS UNSIGNED)
                BETWEEN 1 AND 12
           THEN CONCAT(
               LEFT(TRIM(period_raw), 4),
               LPAD(CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(period_raw), '년', -1), '월', 1)) AS UNSIGNED), 2, '0')
           )
       END AS period_ym,
       passengers
FROM raw_airport_passenger
WHERE airport_name_raw <> '전체 합계';

-- name: create_v_country_monthly
CREATE OR REPLACE VIEW v_country_monthly AS
SELECT region_raw, country_raw, period_raw,
       CASE
           WHEN TRIM(period_raw) REGEXP '^[0-9]{4}년[[:space:]]*[0-9]{1,2}월$'
            AND CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(period_raw), '년', -1), '월', 1)) AS UNSIGNED)
                BETWEEN 1 AND 12
           THEN CONCAT(
               LEFT(TRIM(period_raw), 4),
               LPAD(CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(period_raw), '년', -1), '월', 1)) AS UNSIGNED), 2, '0')
           )
       END AS period_ym,
       passengers
FROM raw_country_passenger
WHERE region_raw <> '전체 합계';

-- name: flight_duplicate_integrity_summary
-- 중복 후보는 삭제하지 않고, 완전 동일 행 여부만 점검한다.
WITH duplicate_groups AS (
    SELECT
        airport_name_raw, flight_date_raw, flight_number_raw, scheduled_time_raw,
        COUNT(*) AS duplicate_rows,
        (COUNT(DISTINCT status_raw) + (SUM(status_raw IS NULL) > 0)) > 1 AS status_differing,
        (COUNT(DISTINCT estimated_time_raw) + (SUM(estimated_time_raw IS NULL) > 0)) > 1 AS estimated_time_differing,
        (COUNT(DISTINCT actual_departure_time_raw) + (SUM(actual_departure_time_raw IS NULL) > 0)) > 1 AS actual_time_differing,
        (COUNT(DISTINCT delay_reason_raw) + (SUM(delay_reason_raw IS NULL) > 0)) > 1 AS delay_reason_differing,
        (COUNT(DISTINCT destination_raw) + (SUM(destination_raw IS NULL) > 0)) > 1 AS destination_differing,
        (COUNT(DISTINCT airline_name_raw) + (SUM(airline_name_raw IS NULL) > 0)) > 1 AS airline_differing,
        (COUNT(DISTINCT service_type_raw) + (SUM(service_type_raw IS NULL) > 0)) > 1 AS service_type_differing
    FROM raw_departure_flight
    GROUP BY airport_name_raw, flight_date_raw, flight_number_raw, scheduled_time_raw
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS duplicate_group_count,
    SUM(duplicate_rows) AS duplicate_row_count,
    SUM(NOT (status_differing OR estimated_time_differing OR actual_time_differing
             OR delay_reason_differing OR destination_differing OR airline_differing
             OR service_type_differing)) AS identical_group_count,
    SUM(status_differing OR estimated_time_differing OR actual_time_differing
        OR delay_reason_differing OR destination_differing OR airline_differing
        OR service_type_differing) AS differing_group_count
FROM duplicate_groups;

-- name: view_row_count_check
-- raw 행 수·집계 행 제외 수·뷰의 원문 행 보존 차이를 함께 확인한다.
SELECT 'v_flight_analysis' AS view_name,
       (SELECT COUNT(*) FROM raw_departure_flight) AS raw_primary_rows,
       NULL AS raw_secondary_rows, 0 AS excluded_primary_rows, NULL AS excluded_secondary_rows,
       (SELECT COUNT(*) FROM v_flight_analysis) AS view_rows,
       (SELECT COUNT(*) FROM raw_departure_flight) - (SELECT COUNT(*) FROM v_flight_analysis) AS primary_row_difference,
       NULL AS secondary_row_difference
UNION ALL
SELECT 'v_route_monthly',
       (SELECT COUNT(*) FROM raw_route_passenger), (SELECT COUNT(*) FROM raw_route_operations),
       (SELECT COUNT(*) FROM raw_route_passenger WHERE origin_airport_raw = '전체 합계'),
       (SELECT COUNT(*) FROM raw_route_operations WHERE origin_airport_raw = '전체 합계'),
       (SELECT COUNT(*) FROM v_route_monthly),
       (SELECT COUNT(*) FROM raw_route_passenger WHERE origin_airport_raw <> '전체 합계')
         - (SELECT COUNT(*) FROM v_route_monthly WHERE passengers IS NOT NULL),
       (SELECT COUNT(*) FROM raw_route_operations WHERE origin_airport_raw <> '전체 합계')
         - (SELECT COUNT(*) FROM v_route_monthly WHERE operations IS NOT NULL)
UNION ALL
SELECT 'v_airline_monthly',
       (SELECT COUNT(*) FROM raw_airline_passenger), (SELECT COUNT(*) FROM raw_airline_operations),
       (SELECT COUNT(*) FROM raw_airline_passenger WHERE airline_name_raw IN ('국적사 계', '외항사 계', '전체 합계')),
       (SELECT COUNT(*) FROM raw_airline_operations WHERE airline_name_raw IN ('국적사 계', '외항사 계', '전체 합계')),
       (SELECT COUNT(*) FROM v_airline_monthly),
       (SELECT COUNT(*) FROM raw_airline_passenger WHERE airline_name_raw NOT IN ('국적사 계', '외항사 계', '전체 합계'))
         - (SELECT COUNT(*) FROM v_airline_monthly WHERE passengers IS NOT NULL),
       (SELECT COUNT(*) FROM raw_airline_operations WHERE airline_name_raw NOT IN ('국적사 계', '외항사 계', '전체 합계'))
         - (SELECT COUNT(*) FROM v_airline_monthly WHERE operations IS NOT NULL)
UNION ALL
SELECT 'v_airport_monthly',
       (SELECT COUNT(*) FROM raw_airport_passenger), NULL,
       (SELECT COUNT(*) FROM raw_airport_passenger WHERE airport_name_raw = '전체 합계'), NULL,
       (SELECT COUNT(*) FROM v_airport_monthly),
       (SELECT COUNT(*) FROM raw_airport_passenger WHERE airport_name_raw <> '전체 합계') - (SELECT COUNT(*) FROM v_airport_monthly), NULL
UNION ALL
SELECT 'v_country_monthly',
       (SELECT COUNT(*) FROM raw_country_passenger), NULL,
       (SELECT COUNT(*) FROM raw_country_passenger WHERE region_raw = '전체 합계'), NULL,
       (SELECT COUNT(*) FROM v_country_monthly),
       (SELECT COUNT(*) FROM raw_country_passenger WHERE region_raw <> '전체 합계') - (SELECT COUNT(*) FROM v_country_monthly), NULL;

-- name: time_calculable_summary
-- v_flight_analysis 생성 뒤 시간 계산 가능 행 수를 공항별로 검증한다.
SELECT airport_name_raw, COUNT(*) AS view_rows,
       SUM(is_time_calculable) AS time_calculable_rows,
       ROUND(SUM(is_time_calculable) / NULLIF(COUNT(*), 0), 4) AS time_calculable_rate
FROM v_flight_analysis
GROUP BY airport_name_raw
ORDER BY airport_name_raw;

-- name: flight_analysis_flag_summary
SELECT
    COUNT(*) AS total_rows,
    SUM(is_passenger) AS passenger_rows,
    ROUND(SUM(is_passenger) / NULLIF(COUNT(*), 0), 4) AS passenger_rate,
    SUM(is_denominator) AS denominator_rows,
    ROUND(SUM(is_denominator) / NULLIF(COUNT(*), 0), 4) AS denominator_rate,
    SUM(is_cancelled) AS cancelled_rows,
    ROUND(SUM(is_cancelled) / NULLIF(COUNT(*), 0), 4) AS cancelled_rate,
    SUM(is_diverted) AS diverted_rows,
    ROUND(SUM(is_diverted) / NULLIF(COUNT(*), 0), 4) AS diverted_rate,
    SUM(is_status_unknown) AS status_unknown_rows,
    ROUND(SUM(is_status_unknown) / NULLIF(COUNT(*), 0), 4) AS status_unknown_rate,
    SUM(is_time_calculable) AS time_calculable_rows,
    ROUND(SUM(is_time_calculable) / NULLIF(COUNT(*), 0), 4) AS time_calculable_rate,
    SUM(is_domestic_reference_match IS TRUE) AS domestic_reference_match_rows,
    SUM(is_domestic_reference_match IS FALSE) AS domestic_reference_nonmatch_rows,
    SUM(is_domestic_reference_match IS NULL) AS domestic_reference_unknown_rows,
    SUM(flight_scope_std = 'domestic') AS domestic_rows,
    SUM(flight_scope_std = 'international') AS international_rows,
    SUM(flight_scope_std = 'unresolved') AS unresolved_rows,
    SUM(flight_scope_std = 'reference_conflict') AS reference_conflict_rows
FROM v_flight_analysis;

-- name: flight_scope_classification_summary
-- 국내·국제·미확정·충돌 범위와 여객편 기준 범위를 함께 검증한다.
SELECT flight_scope_std,
       COUNT(*) AS rows_count,
       ROUND(COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 4) AS row_share,
       SUM(is_passenger) AS passenger_rows,
       ROUND(SUM(is_passenger) / NULLIF(SUM(SUM(is_passenger)) OVER (), 0), 4) AS passenger_share,
       SUM(is_international IS TRUE) AS international_flag_true_rows,
       SUM(is_international IS FALSE) AS international_flag_false_rows,
       SUM(is_international IS NULL) AS international_flag_null_rows
FROM v_flight_analysis
GROUP BY flight_scope_std
ORDER BY FIELD(flight_scope_std, 'international', 'domestic', 'unresolved', 'reference_conflict');

-- name: flight_scope_airport_service_profile
-- 공항·서비스 구분별 국내·국제·미확정·충돌 분포를 확인한다.
SELECT airport_name_raw,
       COALESCE(service_type_raw, '(NULL)') AS service_type_raw,
       flight_scope_std,
       COUNT(*) AS rows_count,
       ROUND(COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY airport_name_raw, COALESCE(service_type_raw, '(NULL)')), 0), 4)
           AS share_within_airport_service
FROM v_flight_analysis
GROUP BY airport_name_raw, COALESCE(service_type_raw, '(NULL)'), flight_scope_std
ORDER BY airport_name_raw, service_type_raw,
         FIELD(flight_scope_std, 'international', 'domestic', 'unresolved', 'reference_conflict');

-- name: standardized_value_change
-- 원문 보존 전제의 표준화가 고유값 수를 어떻게 바꾸는지만 확인한다.
SELECT 'flight_number' AS field_name,
       COUNT(DISTINCT NULLIF(TRIM(flight_number_raw), '')) AS raw_distinct_count,
       COUNT(DISTINCT flight_number_std) AS standardized_distinct_count
FROM v_flight_analysis
UNION ALL
SELECT 'airline', COUNT(DISTINCT NULLIF(TRIM(airline_name_raw), '')), COUNT(DISTINCT airline_std)
FROM v_flight_analysis
UNION ALL
SELECT 'delay_reason', COUNT(DISTINCT NULLIF(TRIM(delay_reason_raw), '')), COUNT(DISTINCT delay_reason_std)
FROM v_flight_analysis;

-- name: delay_reason_standardization_profile
SELECT delay_reason_raw, delay_reason_std, is_reason_operational_outcome, COUNT(*) AS rows_count
FROM v_flight_analysis
GROUP BY delay_reason_raw, delay_reason_std, is_reason_operational_outcome
ORDER BY rows_count DESC, delay_reason_raw;

-- name: diversion_definition_crosscheck
-- 상태값 회항과 지연원인 회항의 관계만 대조하며 회항률 정의는 확정하지 않는다.
SELECT airport_name_raw, service_type_raw, status_raw, delay_reason_raw, COUNT(*) AS rows_count
FROM v_flight_analysis
WHERE status_raw = '회항' OR delay_reason_raw = '회항'
GROUP BY airport_name_raw, service_type_raw, status_raw, delay_reason_raw
ORDER BY rows_count DESC, airport_name_raw, service_type_raw, status_raw, delay_reason_raw;

-- name: destination_standardization_conflicts
-- 하나의 destination_std가 여러 원문 목적지에 매핑되는 충돌을 남긴다.
SELECT destination_std, COUNT(DISTINCT destination_raw) AS raw_value_count,
       SUM(1) AS rows_count,
       GROUP_CONCAT(DISTINCT destination_raw ORDER BY destination_raw SEPARATOR ' | ') AS raw_values
FROM v_flight_analysis
WHERE destination_std IS NOT NULL
GROUP BY destination_std
HAVING COUNT(DISTINCT destination_raw) > 1
ORDER BY raw_value_count DESC, rows_count DESC, destination_std;

-- name: domestic_airport_reference
-- 공식 국내 공항 목록으로 만든 참조 뷰의 전체 값을 확인한다.
SELECT destination_std, airport_canonical_std, airport_code, reference_source
FROM v_domestic_airport_reference
ORDER BY destination_std;

-- name: destination_alias_reference
-- 출발 로그와 국제선 노선 통계 사이의 검토된 명칭 별칭을 확인한다.
SELECT destination_std, destination_canonical_std, scope_std, reference_source
FROM v_destination_alias_reference
ORDER BY destination_std;

-- name: international_destination_reference
-- 국내선 형태 예외를 제외한 국제선 노선 목적지 참조를 확인한다.
SELECT destination_canonical_std, route_destination_raw_values,
       route_destination_raw_count, reference_source
FROM v_international_destination_reference
ORDER BY destination_canonical_std;

-- name: domestic_destination_matching
-- 목적지별 최종 참조 결과를 원문과 함께 확인한다.
SELECT destination_raw, destination_std, destination_canonical_std,
       flight_scope_std, scope_reference_source,
       COUNT(*) AS flight_rows
FROM v_flight_analysis
GROUP BY destination_raw, destination_std, destination_canonical_std,
         flight_scope_std, scope_reference_source
ORDER BY FIELD(flight_scope_std, 'unresolved', 'reference_conflict', 'domestic', 'international'),
         flight_rows DESC, destination_raw;

-- name: unresolved_destination_profile
-- 미확정 목적지는 절단하지 않고 전체를 남겨 후속 검토가 가능하도록 한다.
SELECT destination_raw, destination_std, destination_canonical_std,
       scope_reference_source, COUNT(*) AS flight_rows,
       SUM(is_passenger) AS passenger_rows
FROM v_flight_analysis
WHERE flight_scope_std = 'unresolved'
GROUP BY destination_raw, destination_std, destination_canonical_std, scope_reference_source
ORDER BY flight_rows DESC, destination_raw;

-- name: reference_conflict_profile
-- 국내·국제 참조가 동시에 매칭된 충돌 목적지를 확인한다.
SELECT destination_raw, destination_std, destination_canonical_std,
       scope_reference_source, COUNT(*) AS flight_rows,
       SUM(is_passenger) AS passenger_rows
FROM v_flight_analysis
WHERE flight_scope_std = 'reference_conflict'
GROUP BY destination_raw, destination_std, destination_canonical_std, scope_reference_source
ORDER BY flight_rows DESC, destination_raw;

-- name: monthly_period_parse_check
-- 월별 집계 뷰의 기간 표준화 결과와 NULL 발생 여부를 확인한다.
SELECT 'v_route_monthly' AS view_name, COUNT(*) AS rows_count,
       SUM(period_ym IS NULL) AS period_ym_null_rows,
       MIN(period_ym) AS first_period_ym, MAX(period_ym) AS last_period_ym,
       COUNT(DISTINCT period_ym) AS period_count
FROM v_route_monthly
UNION ALL
SELECT 'v_airline_monthly', COUNT(*), SUM(period_ym IS NULL), MIN(period_ym), MAX(period_ym), COUNT(DISTINCT period_ym)
FROM v_airline_monthly
UNION ALL
SELECT 'v_airport_monthly', COUNT(*), SUM(period_ym IS NULL), MIN(period_ym), MAX(period_ym), COUNT(DISTINCT period_ym)
FROM v_airport_monthly
UNION ALL
SELECT 'v_country_monthly', COUNT(*), SUM(period_ym IS NULL), MIN(period_ym), MAX(period_ym), COUNT(DISTINCT period_ym)
FROM v_country_monthly
ORDER BY view_name;

-- name: aggregate_view_monthly_total_check
-- 01에서 검증한 제외 규칙을 적용한 뒤 raw와 뷰 사이의 월별 합계 보존을 확인한다.
WITH raw_totals AS (
    SELECT 'route_passengers' AS dataset, period_raw, SUM(passengers) AS raw_total
    FROM raw_route_passenger WHERE origin_airport_raw <> '전체 합계' GROUP BY period_raw
    UNION ALL
    SELECT 'route_operations', period_raw, SUM(operations)
    FROM raw_route_operations WHERE origin_airport_raw <> '전체 합계' GROUP BY period_raw
    UNION ALL
    SELECT 'airline_passengers', period_raw, SUM(passengers)
    FROM raw_airline_passenger WHERE airline_name_raw NOT IN ('국적사 계', '외항사 계', '전체 합계') GROUP BY period_raw
    UNION ALL
    SELECT 'airline_operations', period_raw, SUM(operations)
    FROM raw_airline_operations WHERE airline_name_raw NOT IN ('국적사 계', '외항사 계', '전체 합계') GROUP BY period_raw
    UNION ALL
    SELECT 'airport_passengers', period_raw, SUM(passengers)
    FROM raw_airport_passenger WHERE airport_name_raw <> '전체 합계' GROUP BY period_raw
    UNION ALL
    SELECT 'country_passengers', period_raw, SUM(passengers)
    FROM raw_country_passenger WHERE region_raw <> '전체 합계' GROUP BY period_raw
), view_totals AS (
    SELECT 'route_passengers' AS dataset, period_raw, SUM(passengers) AS view_total FROM v_route_monthly GROUP BY period_raw
    UNION ALL SELECT 'route_operations', period_raw, SUM(operations) FROM v_route_monthly GROUP BY period_raw
    UNION ALL SELECT 'airline_passengers', period_raw, SUM(passengers) FROM v_airline_monthly GROUP BY period_raw
    UNION ALL SELECT 'airline_operations', period_raw, SUM(operations) FROM v_airline_monthly GROUP BY period_raw
    UNION ALL SELECT 'airport_passengers', period_raw, SUM(passengers) FROM v_airport_monthly GROUP BY period_raw
    UNION ALL SELECT 'country_passengers', period_raw, SUM(passengers) FROM v_country_monthly GROUP BY period_raw
)
SELECT r.dataset, r.period_raw, r.raw_total, v.view_total,
       CASE WHEN r.raw_total <=> v.view_total THEN 'matched' ELSE 'check' END AS total_check
FROM raw_totals AS r
LEFT JOIN view_totals AS v ON r.dataset = v.dataset AND r.period_raw = v.period_raw
UNION ALL
SELECT v.dataset, v.period_raw, r.raw_total, v.view_total, 'check'
FROM view_totals AS v
LEFT JOIN raw_totals AS r ON r.dataset = v.dataset AND r.period_raw = v.period_raw
WHERE r.dataset IS NULL
ORDER BY dataset, period_raw;

-- name: route_scope_profile
-- 노선 집계의 국내선 형태 예외·국제선·미확정 범위를 삭제 없이 확인한다.
SELECT route_scope_std, COUNT(*) AS rows_count,
       SUM(COALESCE(passengers, 0)) AS passengers,
       SUM(COALESCE(operations, 0)) AS operations
FROM v_route_monthly
GROUP BY route_scope_std
ORDER BY FIELD(route_scope_std, 'international', 'domestic', 'unresolved');

-- name: route_scope_monthly_comparison
-- 국제선 범위 적용 전후 월별 합계와 제외·미확정 값을 비교한다.
SELECT period_ym,
       SUM(COALESCE(passengers, 0)) AS all_passengers,
       SUM(CASE WHEN is_international = TRUE THEN COALESCE(passengers, 0) ELSE 0 END) AS international_passengers,
       SUM(CASE WHEN route_scope_std = 'domestic' THEN COALESCE(passengers, 0) ELSE 0 END) AS domestic_exception_passengers,
       SUM(CASE WHEN route_scope_std = 'unresolved' THEN COALESCE(passengers, 0) ELSE 0 END) AS unresolved_passengers,
       SUM(COALESCE(operations, 0)) AS all_operations,
       SUM(CASE WHEN is_international = TRUE THEN COALESCE(operations, 0) ELSE 0 END) AS international_operations,
       SUM(CASE WHEN route_scope_std = 'domestic' THEN COALESCE(operations, 0) ELSE 0 END) AS domestic_exception_operations,
       SUM(CASE WHEN route_scope_std = 'unresolved' THEN COALESCE(operations, 0) ELSE 0 END) AS unresolved_operations
FROM v_route_monthly
GROUP BY period_ym
ORDER BY period_ym;
