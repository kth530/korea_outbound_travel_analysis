"""Tableau 통합 데이터셋 생성 스크립트.

MySQL 분석 View에서 시장·운항 6개 시트를 만들고, 05 노트북이 저장한
예측 3개 CSV(forecast_destination_monthly / promotion_candidates /
model_performance)와 합쳐 `tableau/tableau_data.xlsx`(안내 + 9개 데이터 시트)를
생성한다. 원본 노트북·SQL·모델 코드는 수정하지 않는다.

실행: python tableau/export_tableau.py
전제: MySQL 실행 중이고 05 노트북이 예측 CSV 3개를 tableau/에 저장한 상태.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd
from dotenv import dotenv_values
from sqlalchemy import create_engine

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import tableau_utils as tu  # noqa: E402

TABLEAU_DIR = ROOT / "tableau"
OUT_XLSX = TABLEAU_DIR / "tableau_data.xlsx"


def make_engine():
    env = dotenv_values(ROOT / ".env")
    url = (
        f"mysql+pymysql://{env['DB_USER']}:{env['DB_PASSWORD']}"
        f"@{env['DB_HOST']}:{env['DB_PORT']}/{env['DB_NAME']}?charset=utf8mb4"
    )
    return create_engine(url)


def to_period_cols(df: pd.DataFrame, ym_col: str) -> pd.DataFrame:
    """YYYYMM 문자열을 기준월(date)·연도·월 컬럼으로 확장한다."""
    ym = df[ym_col].astype(str)
    df = df.copy()
    df["기준월"] = pd.to_datetime(ym + "01", format="%Y%m%d")
    df["연도"] = ym.str[:4].astype(int)
    df["월"] = ym.str[4:6].astype(int)
    return df


def seasonal_index(df: pd.DataFrame, key_cols, value_col: str) -> pd.Series:
    """완전 관측 연도(2023-2025)의 같은 달 평균으로 계절지수를 계산한다.

    지수 = (키별·달별 여객 평균) / (키별 월평균 여객). 03_eda.sql의
    seasonal_demand_profile과 같은 정의(연도 내 평균 대비 비율의 연도 평균).
    """
    full = df[df["연도"].between(2023, 2025)].copy()
    # 연도별 평균 대비 비율
    denom = full.groupby(key_cols + ["연도"])[value_col].transform("mean")
    full["_idx"] = full[value_col] / denom.replace(0, np.nan)
    idx = full.groupby(key_cols + ["월"])["_idx"].mean().rename("계절지수")
    return idx


def build_market_monthly(eng) -> pd.DataFrame:
    q = """
        SELECT period_ym,
               SUM(passengers)  AS passengers,
               SUM(operations)  AS operations
        FROM v_route_monthly
        WHERE is_international = TRUE
        GROUP BY period_ym
        ORDER BY period_ym
    """
    df = pd.read_sql(q, eng)
    df = to_period_cols(df, "period_ym")
    df = df.sort_values("기준월").reset_index(drop=True)
    df["전년동월여객수"] = df.groupby("월")["passengers"].shift(1)
    df["전년대비증감률"] = np.where(
        df["전년동월여객수"] > 0,
        df["passengers"] / df["전년동월여객수"] - 1,
        np.nan,
    )
    # 시장 전체 계절지수(연도 내 평균 대비)
    idx = seasonal_index(df.assign(_k=1), ["_k"], "passengers").reset_index()
    df = df.merge(idx[["월", "계절지수"]], on="월", how="left")
    df["편당여객"] = df["passengers"] / df["operations"].replace(0, np.nan)
    df = df.rename(columns={"passengers": "여객수", "operations": "운항편수"})
    return df[[
        "기준월", "연도", "월", "여객수", "운항편수", "편당여객",
        "전년동월여객수", "전년대비증감률", "계절지수",
    ]]


def build_country_monthly(eng) -> pd.DataFrame:
    q = """
        SELECT period_ym, region_raw, country_raw, passengers,
               passenger_share, previous_year_passengers, passenger_yoy_rate
        FROM v_metric_demand_country_monthly
    """
    df = pd.read_sql(q, eng)
    df = to_period_cols(df, "period_ym")
    df = df.rename(columns={
        "region_raw": "지역",
        "country_raw": "국가",
        "passengers": "여객수",
        "passenger_share": "점유율",
        "previous_year_passengers": "전년동월여객수",
        "passenger_yoy_rate": "전년대비증감률",
    })
    return df[[
        "기준월", "연도", "월", "지역", "국가", "여객수", "점유율",
        "전년동월여객수", "전년대비증감률",
    ]].sort_values(["기준월", "여객수"], ascending=[True, False])


def build_destination_monthly(eng) -> pd.DataFrame:
    q = """
        SELECT period_ym, destination_canonical_std, passengers, operations,
               passenger_share, passengers_per_operation,
               previous_year_passengers, passenger_yoy_rate,
               previous_year_operations, operation_yoy_rate
        FROM v_metric_demand_destination_monthly
    """
    df = pd.read_sql(q, eng)
    df = to_period_cols(df, "period_ym")
    df = tu.add_destination_labels(df, "destination_canonical_std")
    df = df.rename(columns={
        "passengers": "여객수",
        "operations": "운항편수",
        "passenger_share": "점유율",
        "passengers_per_operation": "편당여객",
        "previous_year_passengers": "전년동월여객수",
        "passenger_yoy_rate": "전년대비증감률",
        "previous_year_operations": "전년동월운항편수",
        "operation_yoy_rate": "운항편전년대비증감률",
    })
    idx = seasonal_index(df, ["목적지_DB"], "여객수").reset_index()
    df = df.merge(idx, on=["목적지_DB", "월"], how="left")
    return df[[
        "기준월", "연도", "월", "목적지_DB", "목적지", "국가", "지역",
        "여객수", "운항편수", "편당여객", "점유율", "계절지수",
        "전년동월여객수", "전년대비증감률",
        "전년동월운항편수", "운항편전년대비증감률",
    ]].sort_values(["기준월", "여객수"], ascending=[True, False])


def build_operation_monthly(eng) -> pd.DataFrame:
    q = """
        SELECT operating_month, scheduled_flight_rows,
               status_delay_rate, time_delay_15_rate,
               cancellation_rate, diversion_rate,
               avg_delay_minutes, median_delay_minutes
        FROM v_metric_operation_monthly
    """
    df = pd.read_sql(q, eng)
    df = to_period_cols(df, "operating_month")
    df = df.rename(columns={
        "scheduled_flight_rows": "계획편수",
        "status_delay_rate": "상태지연율",
        "time_delay_15_rate": "15분지연율",
        "cancellation_rate": "취소율",
        "diversion_rate": "회항율",
        "avg_delay_minutes": "평균지연분",
        "median_delay_minutes": "중위지연분",
    })
    return df[[
        "기준월", "연도", "월", "계획편수",
        "상태지연율", "15분지연율", "취소율", "회항율",
        "평균지연분", "중위지연분",
    ]].sort_values("기준월")


def build_operation_destination(eng) -> pd.DataFrame:
    q = """
        SELECT operating_month, destination_canonical_std,
               scheduled_flight_rows, status_delay_rate, time_delay_15_rate,
               cancellation_rate, diversion_rate, avg_delay_minutes
        FROM v_metric_operation_destination_monthly
    """
    df = pd.read_sql(q, eng)
    df = to_period_cols(df, "operating_month")
    df = tu.add_destination_labels(df, "destination_canonical_std")
    df = df.rename(columns={
        "scheduled_flight_rows": "계획편수",
        "status_delay_rate": "상태지연율",
        "time_delay_15_rate": "15분지연율",
        "cancellation_rate": "취소율",
        "diversion_rate": "회항율",
        "avg_delay_minutes": "평균지연분",
    })
    return df[[
        "기준월", "연도", "월", "목적지_DB", "목적지", "국가", "지역",
        "계획편수", "상태지연율", "15분지연율", "취소율", "회항율", "평균지연분",
    ]].sort_values(["기준월", "계획편수"], ascending=[True, False])


def build_delay_reason(eng) -> pd.DataFrame:
    q = """
        SELECT operating_month, airport_name_raw, airline_std,
               destination_canonical_std, delay_reason_category,
               delayed_flight_rows
        FROM v_metric_delay_reason_monthly
    """
    df = pd.read_sql(q, eng)
    df = to_period_cols(df, "operating_month")
    df = tu.add_destination_labels(df, "destination_canonical_std")
    df = df.rename(columns={
        "airport_name_raw": "출발공항",
        "airline_std": "항공사",
        "delay_reason_category": "지연사유",
        "delayed_flight_rows": "지연편수",
    })
    return df[[
        "기준월", "연도", "월", "출발공항", "항공사",
        "목적지_DB", "목적지", "국가", "지역", "지연사유", "지연편수",
    ]].sort_values(["기준월", "지연편수"], ascending=[True, False])


GUIDE_ROWS = [
    ("시장월별", "국제선 전체 월별 여객·운항·계절지수", "기준월"),
    ("국가월별", "목적국가별 월별 여객·점유율·전년대비", "기준월 + 국가"),
    ("목적지월별", "목적지별 월별 여객·운항·계절지수", "기준월 + 목적지_DB"),
    ("전체운항월별", "인천·김포 출발편 전체 월별 운항 안정성", "기준월"),
    ("목적지운항", "목적지별 월별 운항 안정성(지연·취소·회항)", "기준월 + 목적지_DB"),
    ("지연사유", "출발공항·항공사·목적지·사유별 월별 지연편수", "기준월 + 목적지_DB"),
    ("월별예측", "목적지×예측월 2026년 8-12월 예측·구간·증가", "예측월 + 목적지_DB"),
    ("프로모션후보", "인기·성장 후보 목적지 1행 요약", "목적지_DB"),
    ("모델성능", "Validation·Test 모델별 WAPE·순편향", "-"),
]


def build_guide() -> pd.DataFrame:
    return pd.DataFrame(GUIDE_ROWS, columns=["시트", "설명", "연결키"])


def main() -> None:
    eng = make_engine()

    # 6개 시장·운항 시트
    sheets = {
        "시장월별": build_market_monthly(eng),
        "국가월별": build_country_monthly(eng),
        "목적지월별": build_destination_monthly(eng),
        "전체운항월별": build_operation_monthly(eng),
        "목적지운항": build_operation_destination(eng),
        "지연사유": build_delay_reason(eng),
    }

    # 3개 예측 시트(05 노트북이 저장한 CSV)
    csv_map = {
        "월별예측": "forecast_destination_monthly.csv",
        "프로모션후보": "promotion_candidates.csv",
        "모델성능": "model_performance.csv",
    }
    for sheet, fname in csv_map.items():
        path = TABLEAU_DIR / fname
        if not path.exists():
            raise FileNotFoundError(
                f"{fname} 없음 — 먼저 05_demand_forecast.ipynb를 실행해 예측 CSV를 생성하세요."
            )
        sheets[sheet] = pd.read_csv(path, encoding="utf-8-sig")

    # 검증
    mk = sheets["시장월별"]
    assert mk.shape[0] == 36, f"시장월별 월수 {mk.shape[0]}"
    fc = sheets["월별예측"]
    aug = fc[(fc["연도"] == 2026) & (fc["월"] == 8)]["예측수요"].sum()
    total = fc["예측수요"].sum()
    print(f"[검증] 2026-08 예측 합계 = {aug:,.0f}  (기준 4,159,692)")
    print(f"[검증] 2026 8-12 예측 합계 = {total:,.0f}  (기준 20,416,998)")
    perf = sheets["모델성능"]
    test = perf[(perf["평가구간"] == "Test") & (perf["예측거리"] == "전체")]
    print(f"[검증] Test WAPE = {test['WAPE'].iloc[0]:.4f}  순편향 = {test['순편향'].iloc[0]:.4f}")

    with pd.ExcelWriter(OUT_XLSX, engine="openpyxl") as xw:
        build_guide().to_excel(xw, sheet_name="안내", index=False)
        for name, df in sheets.items():
            # date 컬럼을 Excel에서 순수 날짜로 저장
            df.to_excel(xw, sheet_name=name, index=False)
    print(f"\n저장 완료: {OUT_XLSX}")
    for name, df in sheets.items():
        print(f"  {name:8} {df.shape[0]:>6,}행 × {df.shape[1]}열")


if __name__ == "__main__":
    main()
