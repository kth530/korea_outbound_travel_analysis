# 국제선 목적지×월 수요 예측

해외여행 플랫폼의 프로모션 검토를 가정하고, 전국 공항의 국제선 출발 여객 수요로 목적지별 규모·최근 변화·여행 시기를 분석한다. 2026년 7월까지 관측된 월별 수요를 바탕으로 169개 목적지의 2026년 8–12월 수요를 예측한다. 결과는 캠페인을 집행할 목적지의 확정 순위가 아니라 추가 검토할 후보 목록이다.

## 분석 흐름

| 단계 | 질문 | 파일 |
|---|---|---|
| 01 문제 정의 | 기존 인기 목적지와 최근 성장 목적지를 어떻게 구분하고, 목적지별 수요 시기를 어떻게 볼 것인가? | [문제·가설](notebooks/01_problem_hypothesis.md) |
| 02 적재·전처리 | 노선 Excel의 합계 행·국제선 범위·목적지 이름을 어떻게 처리하는가? | [데이터 준비](notebooks/02_data_preparation.ipynb) |
| 03 데이터 확인 | 시장 36개월, 목적지×월 6,493행, 모델 대상 169곳은 어떻게 구성되는가? | [데이터 개요](notebooks/03_data_overview.ipynb) |
| 04 관측 수요 분석 | 기존 인기 목적지 외에 최근 성장 목적지가 있는가? 목적지별 수요 최고월은 어떻게 다른가? | [EDA·가설 판단](notebooks/04_eda_validation.ipynb) |
| 05 예측·검증 | 어떤 모델을 채택하며, 어느 목적지×월을 먼저 확인할 것인가? | [모델링·후보](notebooks/05_modeling_validation.ipynb) |
| 06 사후 검증 | 7월 기준 예측은 실제 8·9월 수요와 얼마나 달랐는가? | [8·9월 오차 확인](notebooks/06_postproject_validation.ipynb) |

2023–2025년 노선 여객·운항 Excel 6개를 적재하고, 같은 형식의 2026년 1–7월 자료 2개를 별도로 결합한다. 편별 출발 로그의 지연·취소 지표는 이 목적지×월 수요 분석의 입력이나 후보 점수에 사용하지 않는다. 노선 <strong>운항 편수</strong>는 여객 수요와 함께 모델 입력으로 사용한다. SQL 단계별 정의는 [SQL 안내](sql/README.md)에 있다.

## 관측 결과와 모델 선택

2023–2025년 누적 인기 상위 10곳 중 9곳은 2025년 수요 상위 10곳에도 포함된다. 반면 2024→2025년 증가 <strong>인원</strong> 상위 10곳 가운데 6곳은 누적 인기권 밖이다. 증가율도 함께 확인하되 작은 시장의 높은 비율과 실제 증가 인원을 구분한다. 기존 인기·증가 인원·증가율 상위 목적지를 각각 5곳씩 그린 계절지수 히트맵에서는 집단별 최고월 차이를 확인할 수 있다. 방콕은 1월, 북경·멕시코는 8월, 나고야·쿤밍은 10월에 상대 수요가 가장 높다.

| 모델 | 2025년 Rolling Validation WAPE | 판단 |
|---|---:|---|
| B1+Ridge 잔차 보정 | **11.47%** | **선택** |
| B1 전년동월×안전 성장계수 | 11.84% | 비교 모델 |
| B0 전년동월 | 14.09% | 단순 기준선 |

모델은 2025년 Rolling Validation WAPE가 가장 낮은 Ridge 잔차보정으로 선택했다. 선택한 **Ridge 한 모델만 2026년 1–7월 Fixed Test**에 적용했으며 WAPE는 **13.32%**다. Test 결과로 모델이나 설정을 다시 고르지 않았다. 전체 모델의 Validation WAPE·순편향·h1–h5는 [모델링 노트북](notebooks/05_modeling_validation.ipynb)의 오름차순 비교표에서 확인할 수 있다.

## 2026년 8–12월 검토 후보

관측 수요 분석에서 확인한 인기·증가 인원·증가율·계절성의 차이를 후보 기준에 반영한다. 관측 순위를 그대로 옮기지 않고 2025년 인기와 2026년 예측 증가·규모·지속성을 다시 평가한다.

선택한 Ridge로 169개 목적지의 2026년 8–12월을 예측한 결과는 **845행**, 합계 **20,416,998명**이다. 2025년 연간 인기 상위 20곳과 규모·증가·지속성 조건을 통과한 성장 후보 35곳, 총 **55곳**은 넓은 1차 검토 후보군이다. 캠페인을 55곳에 동시에 집행한다는 뜻은 아니다.

| 검토 방향 | 목적지 수 | 뜻 | 추가로 확인할 사항 |
|---|---:|---|---|
| 인기 | 11 | 인기 20곳 중 전년보다 예측 수요가 증가 | 상품·좌석 재고와 수익성 |
| 성장 | 32 | 성장 조건을 통과한 목적지 중 탐색 3곳을 제외 | 예상 증가 인원과 지속 월수 |
| 탐색 | 3 | 성장 조건 통과 목적지 중 별도 표시한 타이중·히로시마·시즈오카 | 소규모 실험의 적합성 |
| 방어 | 9 | 인기 20곳 중 전년보다 예측 수요가 감소 | 감소 원인과 가격·공급 변화 |

먼저 살펴볼 검토 범위는 트랙별 최대 5곳, 총 **18곳**이다. 집행 가능성은 인기의 **오사카 간사이·도쿄 나리타·후쿠오카·타이베이·상하이 푸둥**과 성장의 **가오슝·지난·광저우·다롄·시애틀**에서 확인한다. 탐색의 **타이중·히로시마·시즈오카**는 실험 적합성을, 방어의 **다낭·방콕·나트랑 깜라인·마닐라·싱가포르**는 감소 원인을 살펴본다. **55곳 전체 이름과 선정 조건**은 [모델링 노트북](notebooks/05_modeling_validation.ipynb)의 마지막 절에 있다. 검토 순서는 캠페인 수익률 순위와 구분한다.

`성수월`은 과거 계절지수가 가장 높은 월이고, `추천월`은 2026년 8–12월 Ridge 예측 수요가 가장 높은 월이다. 추천월이 최적 캠페인 시작일을 뜻하지는 않는다. 가격·좌석·예약·마진·캠페인 비용과 순증 효과를 확인한 뒤 집행 여부를 판단해야 한다.

## 프로젝트 종료 후 확인

2026년 7월 기준 예측을 그대로 두고, 10월 11일에 확보한 8·9월 실제 여객과 비교했다. 169개 목적지 기준 WAPE는 **8월 9.15%**, **9월 9.65%**, **두 달 합계 9.39%**였다. 두 달 모두 과소예측했다. 이는 모델 재선정이나 캠페인 성과 평가가 아니라 [06 사후 검증](notebooks/06_postproject_validation.ipynb)의 미래 실적 대조다.

## 재현

`.env`에 MySQL 연결 정보를 넣고 `data/raw/airportal/`, `data/raw_2026/airportal/`에 노선 Excel을 준비한다. Python 3.10의 `ml_env` 환경을 활성화한 뒤 저장소 루트에서 다음 순서로 실행한다.

```bash
python -m pip install -r requirements.txt
python -m ipykernel install --user --name ml_env --display-name "Python (ml_env)"
python -m nbconvert --to notebook --execute --inplace --ExecutePreprocessor.kernel_name=ml_env notebooks/02_data_preparation.ipynb
python -m nbconvert --to notebook --execute --inplace --ExecutePreprocessor.kernel_name=ml_env notebooks/03_data_overview.ipynb
python -m nbconvert --to notebook --execute --inplace --ExecutePreprocessor.kernel_name=ml_env notebooks/04_eda_validation.ipynb
python -m nbconvert --to notebook --execute --inplace --ExecutePreprocessor.kernel_name=ml_env notebooks/05_modeling_validation.ipynb
python -m nbconvert --to notebook --execute --inplace --ExecutePreprocessor.kernel_name=ml_env notebooks/06_postproject_validation.ipynb
```

06 실행에는 저장소의 `data/raw_followup_2026/airportal/transport_statistics/route/`에 있는 8·9월 여객·운항 Excel과 고정된 `tableau/forecast_destination_monthly.csv`가 필요하다. 원자료 조회 조건과 해시는 [사후 자료 기록](data/raw_followup_2026/source_manifest.json)에 있다.

[Ridge 월별 예측 CSV](tableau/forecast_destination_monthly.csv)와 [검토 후보 CSV](tableau/promotion_candidates.csv)는 7월 기준 예측을 고정한 저장 산출물이다. 06은 이 예측을 8·9월 실적과 비교한다. 모델별 계산과 후보 선정 과정은 05에, 이전 00–05 노트북과 대시보드 파일은 Git 이력에 남아 있다.
