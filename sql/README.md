# SQL 계층과 실행 순서

| 순서 | 파일 | 역할 |
|---:|---|---|
| 1 | `00_elt_pipeline.sql` | 노선 여객·운항 raw 테이블과 파일 해시·적재 배치 이력 |
| 2 | `01_raw_overview.sql` | 원본 컬럼·행 수·결측·합계 행과 세부 행의 월별 대조 |
| 3 | `02_preprocessing_views.sql` | 국내 공항 참조, 노선 월별 결합, 국제선 범위·목적지 키 표준화와 정합성 |
| 4 | `00b_2026_route_holdout.sql` | 2026년 노선 여객·운항 2개 파일의 별도 적재와 동일한 월별 뷰 |
| 5 | `03_eda.sql` | 전체 시장 월별 추이와 연도 내 월평균 대비 계절지수 |
| 6 | `04_business_metrics.sql` | 목적지 월별 수요, 누적 인기, 최근 증가 인원, 목적지별 계절성 |
| 7 | `05_demand_forecast.sql` | 2023–2026년 목적지×월 패널과 관측 길이 프로필 |

`02_data_preparation.ipynb`가 1–4와 7의 정적 입력·뷰를 준비한다. `04_eda_validation.ipynb`가 5–6의 관측 수요를 분석한다. 기준월에 따라 달라지는 피처·타깃·성장계수는 `scripts/feature_layer.py`가 as-of-origin 방식으로 생성한다. 2025년 Rolling Validation, 2026년 Fixed Test, 2026년 7월 기준 미래 예측은 각각 사용할 수 있는 정보의 끝이 다르다.

이 SQL은 목적지×월 수요 문제에 필요한 노선 여객·운항만 다룬다. 편별 출발 로그의 지연·취소 지표와 항공사·국가별 별도 집계는 모델 입력에 쓰지 않는다. 노선 운항 <strong>편수</strong>는 패널에 남긴다.
