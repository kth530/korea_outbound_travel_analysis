# ETL 테이블과 SQL 조회 계층

| 순서 | 파일 | 역할 |
|---:|---|---|
| 1 | `00_etl_pipeline.sql` | Python에서 만든 노선·목적지 테이블의 MySQL 스키마 |
| 2 | `01_etl_quality.sql` | 적재 행 수·국제선 범위·월별 노선/목적지 합계 검산 |
| 3 | `02_analysis_views.sql` | 국내 공항 참조와 기간별 노선 테이블의 읽기 뷰 |
| 4 | `03_eda.sql` | 전체 시장 월별 추이와 연도 내 월평균 대비 계절지수 |
| 5 | `04_business_metrics.sql` | 목적지 월별 수요, 누적 인기, 최근 증가 인원, 목적지별 계절성 |
| 6 | `05_demand_forecast.sql` | 목적지×월 패널·프로필 읽기 뷰와 모델 입력 검산 |

`02_data_preparation.ipynb`는 원천 Excel을 검사한 다음 `scripts/route_etl.py`로 국제선 노선과 목적지×월 자료를 만들고 MySQL에 적재한다. 1–3과 6은 적재 결과를 저장·확인하는 계층이다. `04_eda_validation.ipynb`는 4–5로 관측 수요를 분석한다. 기준월에 따라 달라지는 피처·타깃·성장계수는 `scripts/feature_layer.py`가 as-of-origin 방식으로 생성한다. 2025년 Rolling Validation, 2026년 Fixed Test, 2026년 7월 기준 미래 예측은 각각 사용할 수 있는 정보의 끝이 다르다.

이 SQL은 목적지×월 수요 문제에 필요한 노선 여객·운항만 다룬다. 편별 출발 로그의 지연·취소 지표와 항공사·국가별 별도 집계는 모델 입력에 쓰지 않는다. 노선 운항 <strong>편수</strong>는 패널에 남긴다.
