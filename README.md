# 국제선 수요 예측과 프로모션 후보 선정

[AirPortal 항공통계](https://www.airportal.go.kr/stats/transport/chartDetail5.do)의 국내 공항발 국제선 노선 자료를 활용한 포트폴리오 프로젝트다. 해외여행 플랫폼의 프로모션 대상 검토를 가정하고, 관측 수요의 규모·성장·계절성을 분석한 뒤 목적지별 월간 수요를 예측했다.

> 이미 인기 있는 목적지와 최근 수요가 커진 목적지를 어떻게 구분하고, 어느 목적지의 어느 달을 먼저 검토할까?

[분석 스토리(노션)](https://app.notion.com/p/3daec47c108581aeb741f1ece100c864)

---

## 1. 문제 정의와 가설

2026년 하반기 프로모션을 검토할 때 누적 여객 수만 보면 최근 성장한 목적지를 놓칠 수 있다. 목적지마다 수요가 몰리는 달도 달라, 후보와 시기를 함께 살펴봤다.

- **가설 1.** 누적 여객이 많은 목적지는 최근에도 큰 수요를 보이겠지만, 최근 증가 인원 상위에는 누적 인기 상위권 밖의 목적지도 포함될 것이다.
- **가설 2.** 목적지별로 과거 수요가 가장 많은 달은 서로 다를 것이다.

---

## 2. 분석 기준

- **자료·범위:** 2023년 1월부터 2026년 9월까지의 국내 공항발 국제선 출발 여객·운항 통계. 출발 공항은 인천·김포를 비롯해 해당 기간에 국제선 운항이 관측된 국내 공항을 포함한다.
- **분석 단위:** 노선 원자료를 목적지×월로 합산한다. 2023–2025년 시장 집계는 **36개월**, 목적지×월 집계는 **6,493행·관측 목적지 275곳**이다.
- **기간 구분:** 2023–2025년은 관측 수요 분석과 모델 학습, 2025년 1–7월은 Rolling Validation, 2026년 1–7월은 선택 모델의 Fixed Test에 사용했다. 2026년 7월 기준으로 8–12월을 예측하고, 이후 확보한 8–9월 실적으로 사후 오차를 확인했다.
- **예측 대상:** 2026년 7월 기준 관측 이력이 충분한 **169개 목적지**다. 275곳은 관측된 전체 목적지 수이며, 169곳은 예측과 후보 검토에 사용한 집합이다.

Excel 적재, 국제선 판별과 목적지 이름 표준화는 [02 데이터 준비](notebooks/02_data_preparation.ipynb)와 [SQL](sql/README.md)에, 예측 기준월마다 사용할 수 있는 정보로 피처를 만드는 과정은 [05 모델링](notebooks/05_modeling_validation.ipynb)에 담았다.

---

## 3. 검증 결과

### 인기·성장·계절성

2023–2025년 누적 인기 상위 10곳 중 **9곳**은 2025년 수요 상위 10곳에도 들어갔다. 한편 2024년 대비 2025년 증가 인원 상위 10곳 중 **6곳**은 누적 인기 상위권 밖이었다. 증가율을 함께 살펴 작은 시장의 높은 비율과 실제 증가 인원도 구분했다.

기존 인기·증가 인원·증가율 상위 목적지의 계절지수를 비교하면 수요 최고월이 서로 달랐다. 예를 들어 방콕은 1월, 북경·멕시코는 8월, 나고야·쿤밍은 10월에 상대 수요가 가장 높았다. 차트와 가설별 판단은 [04 EDA](notebooks/04_eda_validation.ipynb)에 있다.

### 예측 모델

| 모델 | 2025년 Rolling Validation WAPE |
|---|---:|
| 전년동월 수요 × 안전 성장계수 + Ridge 잔차 보정 | **11.47%** |
| 전년동월 수요 × 안전 성장계수 | 11.84% |
| 전년동월 수요 | 14.09% |

Validation WAPE가 가장 낮은 **Ridge 잔차 보정 모델**을 선택했다. 이 모델의 2026년 1–7월 Fixed Test WAPE는 **13.32%**였다. 2026년 7월 기준 8–12월 예측은 **169개 목적지×5개월, 845행·20,416,998명**이다. 모델 설계, 예측거리별 검증과 결과는 [05 모델링](notebooks/05_modeling_validation.ipynb)에 있다.

7월에 고정한 예측을 이후 확인된 실적과 비교한 결과, 169개 목적지의 WAPE는 **2026년 8월 9.15%, 9월 9.65%, 두 달 합계 9.39%**였다. 두 달 모두 실제 수요보다 낮게 예측했다. 목적지별 오차는 [06 사후 검증](notebooks/06_postproject_validation.ipynb)에 있다.

---

## 4. 프로모션 검토 방향

2025년 인기와 2026년 예측 수요의 규모·증가·지속성을 함께 살펴 **55개 목적지**를 1차 후보군으로 정리했다. 그중 검토 순서를 제시할 곳은 트랙별 최대 5곳, 총 **18곳**이다.

| 검토 트랙 | 먼저 살펴볼 목적지 | 확인할 내용 |
|---|---|---|
| 인기 | 오사카 간사이·도쿄 나리타·후쿠오카·타이베이·상하이 푸둥 | 상품·좌석 재고와 수익성 |
| 성장 | 가오슝·지난·광저우·다롄·시애틀 | 예상 증가 인원과 지속성 |
| 탐색 | 타이중·히로시마·시즈오카 | 소규모 실험의 적합성 |
| 방어 | 다낭·방콕·나트랑 깜라인·마닐라·싱가포르 | 예상 감소의 원인과 가격·공급 변화 |

과거 계절지수의 최고월은 **성수월**, 2026년 8–12월 예측 수요의 최고월은 **추천월**이다. 집행 시점과 대상은 가격·좌석·예약 흐름, 마진, 캠페인의 순증 효과를 추가 확인해 정한다. 이 프로젝트의 결과는 관측 여객·예측 여객·검토 후보이며, 캠페인 효과는 후속 실험에서 측정할 대상이다.

---

## 5. 분석 자료와 재현

| 자료 | 내용 |
|---|---|
| [01 문제 정의·가설](notebooks/01_problem_hypothesis.md) | 업무 질문과 두 가설 |
| [02 데이터 준비](notebooks/02_data_preparation.ipynb) | Excel 적재, 품질 점검, 국제선·목적지 표준화 |
| [03 데이터 개요](notebooks/03_data_overview.ipynb) | 시장·목적지·운항 자료의 단위와 기간 |
| [04 EDA·가설 판단](notebooks/04_eda_validation.ipynb) | 인기·성장·계절성의 비교와 결론 |
| [05 모델링·후보](notebooks/05_modeling_validation.ipynb) | 모델 선택·검증, 미래 예측과 후보 선정 |
| [06 사후 검증](notebooks/06_postproject_validation.ipynb) | 2026년 8·9월 예측과 실적의 오차 |
| [SQL 기준본](sql/README.md) | 적재·전처리·집계 뷰와 실행 순서 |

재현에는 MySQL, Python 3.10, [환경 변수 예시](.env.example)를 참고한 접속 정보, AirPortal에서 내려받은 2023–2025년 및 2026년 1–7월 노선별 여객·운항 Excel이 필요하다. 두 원자료 디렉터리 `data/raw/`와 `data/raw_2026/`는 공개 저장소에서 제외했다. 8–9월 사후 검증 자료와 조회 조건은 [자료 기록](data/raw_followup_2026/source_manifest.json)에 포함되어 있다.

저장소 루트에서 의존성을 설치하고 노트북 02→06을 차례대로 실행한다.

```bash
conda create -n ml_env python=3.10 -y
conda activate ml_env
python -m pip install -r requirements.txt
python -m ipykernel install --user --name ml_env --display-name "Python (ml_env)"
python -m nbconvert --to notebook --execute --inplace --ExecutePreprocessor.kernel_name=ml_env notebooks/02_data_preparation.ipynb
python -m nbconvert --to notebook --execute --inplace --ExecutePreprocessor.kernel_name=ml_env notebooks/03_data_overview.ipynb
python -m nbconvert --to notebook --execute --inplace --ExecutePreprocessor.kernel_name=ml_env notebooks/04_eda_validation.ipynb
python -m nbconvert --to notebook --execute --inplace --ExecutePreprocessor.kernel_name=ml_env notebooks/05_modeling_validation.ipynb
python -m nbconvert --to notebook --execute --inplace --ExecutePreprocessor.kernel_name=ml_env notebooks/06_postproject_validation.ipynb
```

[7월 기준 월별 예측](outputs/forecast_destination_monthly_2026_07.csv)과 [55개 후보 목록](outputs/promotion_candidates_2026_07.csv)은 사후 검증에 사용한 고정 산출물이다.

---

## 6. 기술 스택

![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=mysql&logoColor=white)
![Jupyter](https://img.shields.io/badge/Jupyter-F37626?style=flat-square&logo=jupyter&logoColor=white)
