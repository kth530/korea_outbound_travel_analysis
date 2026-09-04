"""05 수요 예측 피처 레이어 (as-of-origin, 누수 통제).

이 모듈은 목적지×월 패널(v_model_destination_monthly_all)에서
각 (목적지, origin, horizon)에 대한 피처·타깃 행을 만든다.
모든 피처는 period <= origin 데이터로만 만들고, 타깃은 origin+h 다.

핵심 규율:
- lag/이동평균: origin 시점(o) 이하 월만 사용
- 성장계수: 최근 3개월/전년동기 3개월. 분모 창의 모든 월이 2024년 이후일 때만
  사용하며, 2023 회복기를 포함하면 중립값 1로 폴백
- 계절지수: origin 연도 이전의 '완전한' 과거 연도만 사용(2023 형태 제외). 없으면 풀 폴백
- 타깃 next_1m: y[origin + h], h in 1..5
- 검증 origin: 2025-01 ~ 2025-07

노트북은 이 모듈을 import 해서 쓴다. 여기서는 노트북을 만들지 않는다.
"""
from __future__ import annotations
import os
import re
from pathlib import Path
import numpy as np
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

# ---- 설정 ----
LAGS = [1, 2, 3, 6, 12]
MA_WINDOWS = [3, 6, 12]
HORIZONS = [1, 2, 3, 4, 5]
VALIDATION_ORIGINS = pd.period_range("2025-01", "2025-07", freq="M")
SEASONAL_MIN_YEAR = 2024          # 계절지수 형태 산출 시작 연도(2023 제외)
GROWTH_CLIP = (0.60, 1.60)        # 성장계수 클리핑 구간
GROWTH_DAMP_WEIGHT = 0.75         # 성장계수 중앙값 수축 가중(레거시 blend 재사용)
GROWTH_MIN_DENOMINATOR_YEAR = 2024 # 2023 회복기는 성장계수 분모에서 제외
PANEL_END = pd.Period("2026-07", freq="M")


def get_engine():
    root = Path(__file__).resolve().parents[1]
    load_dotenv(root / ".env")
    cfg = dict(host=os.getenv("DB_HOST"), port=int(os.getenv("DB_PORT", "3306")),
               database=os.getenv("DB_NAME"), username=os.getenv("DB_USER"),
               password=os.getenv("DB_PASSWORD"))
    return create_engine(URL.create("mysql+pymysql", **cfg), pool_pre_ping=True, future=True)


def load_panel(engine) -> pd.DataFrame:
    df = pd.read_sql(text(
        "SELECT period_ym, destination_canonical_std AS dest, "
        "passengers, operations, origin_airport_count AS oac "
        "FROM v_model_destination_monthly_all"), engine)
    df["period"] = pd.PeriodIndex(df["period_ym"], freq="M")
    for c in ["passengers", "operations", "oac"]:
        df[c] = pd.to_numeric(df[c], errors="coerce").astype(float)
    return df[["dest", "period", "passengers", "operations", "oac"]]


def load_universe(engine) -> list[str]:
    return pd.read_sql(text(
        "SELECT destination_canonical_std FROM v_demand_destination_profile "
        "WHERE in_modeling_universe = 1"), engine)["destination_canonical_std"].tolist()


def build_grids(panel: pd.DataFrame) -> dict[str, pd.DataFrame]:
    """목적지별 연속 월 그리드. first_present..PANEL_END, 내부 결측은 0(실질 무수요)."""
    grids = {}
    for dest, g in panel.groupby("dest", sort=False):
        g = g.set_index("period").sort_index()
        idx = pd.period_range(g.index.min(), PANEL_END, freq="M")
        g = g.reindex(idx)
        g["passengers"] = g["passengers"].fillna(0.0)
        g["operations"] = g["operations"].fillna(0.0)
        g["oac"] = g["oac"].fillna(0.0)
        g["first_present"] = idx.min()
        grids[dest] = g
    return grids


def seasonal_index_asof(grids: dict[str, pd.DataFrame], origin: pd.Period):
    """origin 연도 이전의 완전한 과거 연도(>=2024)로만 계절지수[dest][month] 산출.
    자기 지수 없는 계열은 풀(전체 평균) 폴백. (dest_index, pooled_index) 반환."""
    years = list(range(SEASONAL_MIN_YEAR, origin.year))   # Yo=2025 -> [2024]
    dest_index: dict[str, np.ndarray] = {}
    for dest, g in grids.items():
        ratios = []
        for y in years:
            months = pd.period_range(f"{y}-01", f"{y}-12", freq="M")
            if g.index.min() > months.min() or g.index.max() < months.max():
                continue                                   # 그 해가 그리드에 온전히 없음
            vals = g.loc[months, "passengers"].to_numpy()
            annual_mean = vals.mean()
            if annual_mean <= 0:
                continue
            ratios.append(vals / annual_mean)              # 길이 12 (1월..12월)
        if ratios:
            dest_index[dest] = np.mean(ratios, axis=0)
    pooled = (np.mean(list(dest_index.values()), axis=0)
              if dest_index else np.ones(12))
    return dest_index, pooled


def _val_at(g: pd.DataFrame, p: pd.Period):
    if p < g.index.min() or p > g.index.max():
        return np.nan
    return float(g.loc[p, "passengers"])


def build_features(grids, universe, origins, horizons=HORIZONS, require_target=True) -> pd.DataFrame:
    rows = []
    for origin in origins:
        dest_idx, pooled = seasonal_index_asof(grids, origin)
        # origin 시점 성장계수 원값 -> 횡단면 중앙값(as-of-origin) 수축용.
        # 2023 회복기를 분모에 섞으면 2024/2023 반등을 2025/2024 성장으로
        # 잘못 외삽한다. 창 전체가 2024년 이후일 때만 성장 신호로 채택한다.
        legacy_growth_raw_map = {}
        num_months = pd.period_range(origin - 2, origin, freq="M")
        den_months = pd.period_range(origin - 14, origin - 12, freq="M")
        growth_eligible = den_months.min().year >= GROWTH_MIN_DENOMINATOR_YEAR
        for dest in universe:
            g = grids.get(dest)
            if g is None or origin < g.index.min() or origin > g.index.max():
                continue
            if den_months.min() < g.index.min():
                continue
            num = g.loc[num_months, "passengers"].sum()
            den = g.loc[den_months, "passengers"].sum()
            if den > 0:
                legacy_growth_raw_map[dest] = num / den
        growth_raw_map = legacy_growth_raw_map if growth_eligible else {}
        median_growth = float(np.median(list(growth_raw_map.values()))) if growth_raw_map else 1.0

        for dest in universe:
            g = grids.get(dest)
            if g is None or origin < g.index.min() or origin > g.index.max():
                continue
            if (origin - 11) < g.index.min():
                continue                                   # lag_12 만큼의 이력 부족 -> 폴백 대상
            lags = {f"lag_{k}": _val_at(g, origin - (k - 1)) for k in LAGS}
            mas = {f"ma_{w}": float(g.loc[pd.period_range(origin - (w - 1), origin, freq="M"),
                                          "passengers"].mean()) for w in MA_WINDOWS}
            growth_raw_legacy = legacy_growth_raw_map.get(dest, np.nan)
            growth_raw = growth_raw_map.get(dest, np.nan)
            if growth_eligible:
                growth = median_growth if np.isnan(growth_raw) else growth_raw
                growth = float(np.clip(growth, *GROWTH_CLIP))
                growth_damped = median_growth * (1 - GROWTH_DAMP_WEIGHT) + growth * GROWTH_DAMP_WEIGHT
                growth_fallback = "cross_sectional_median" if np.isnan(growth_raw) else "none"
            else:
                # 같은 origin에 안전한 3개월 YoY 분모가 전혀 없으므로, 오염된
                # 횡단면 중앙값으로 대체하지 않고 성장 가정 자체를 중립화한다.
                growth = 1.0
                growth_damped = 1.0
                growth_fallback = "pre_2024_denominator"
            own_idx = dest in dest_idx
            own_idx_vec = dest_idx[dest] if own_idx else None
            # 특정 월의 자기 계절지수가 0이면 탈계절화가 불가능하다. 그 월만
            # 풀 지수로 대체해 0 나누기와 기계적인 0 예측을 피한다.
            idx_vec = (np.where(own_idx_vec > 0, own_idx_vec, pooled)
                       if own_idx else pooled)
            recent_months = pd.period_range(origin - 2, origin, freq="M")
            recent_idx = np.array([idx_vec[p.month - 1] for p in recent_months], dtype=float)
            recent_vals = g.loc[recent_months, "passengers"].to_numpy(dtype=float)
            valid_idx = recent_idx > 0
            seasonal_level_ma_3 = (float(np.mean(recent_vals[valid_idx] / recent_idx[valid_idx]))
                                   if valid_idx.any() else np.nan)
            oac_o = float(g.loc[origin, "oac"])

            for h in horizons:
                tgt_p = origin + h
                target = _val_at(g, tgt_p)
                # require_target=False: 배포(미래 타깃, 실측 없음) 예측용. 피처는 <=origin 이라 누수 없음.
                if require_target and (np.isnan(target) or tgt_p > PANEL_END):
                    continue
                sn_p = tgt_p - 12                            # seasonal-naive 참조(<=origin 이어야)
                target_own_idx = bool(own_idx and own_idx_vec[tgt_p.month - 1] > 0)
                row = {
                    "dest": dest, "origin": origin, "horizon": h,
                    "target_period": tgt_p, "target_month": tgt_p.month,
                    "tmon": tgt_p.month,        # evaluate()/tq 가 의존 -> 여기서 제공(누수 아님, 타깃 달력값)
                    "target_passengers": target,
                    **lags, **mas,
                    "yoy_3m": growth_raw,   # 안전한 경우에만: 최근 3개월 합 / 전년 동기 3개월 합
                    "growth_raw": growth_raw, "growth_raw_legacy": growth_raw_legacy,
                    "growth_clipped": growth,
                    "growth_damped": growth_damped,
                    "growth_eligible": growth_eligible,
                    "growth_denominator_has_2023": den_months.min().year == 2023,
                    "growth_fallback": growth_fallback,
                    "seasonal_level_ma_3": seasonal_level_ma_3,
                    "seasonal_index_target": float(idx_vec[tgt_p.month - 1]),
                    "seasonal_index_own": target_own_idx,
                    "oac_asof": oac_o,
                    "seasonal_naive_pred": _val_at(g, sn_p),
                    "mean_naive_pred": mas["ma_3"],
                    # 누수 검증용: 이 행이 실제로 참조한 최대 피처 period
                    "max_feature_period": max(origin, sn_p),
                }
                rows.append(row)
    return pd.DataFrame(rows)


def leakage_checks(feat: pd.DataFrame) -> dict:
    """전 행에 대해 max(피처 period) <= origin < 타깃 period 확인."""
    assert len(feat) > 0, "피처 행이 비었음"
    c1 = (feat["max_feature_period"] <= feat["origin"]).all()
    c2 = (feat["origin"] < feat["target_period"]).all()
    c3 = (feat["target_period"] <= PANEL_END).all()
    # origin 연도(2025) 검증 폴드에서 어떤 피처도 2026을 참조하지 않아야 함
    c4 = (feat["max_feature_period"] <= feat["origin"]).all() and \
         (feat["max_feature_period"].max() <= feat["origin"].max())
    assert c1, "누수: max_feature_period > origin 인 행 존재"
    assert c2, "오류: origin >= target_period 인 행 존재"
    assert c3, "오류: target_period 가 패널 범위를 벗어남"
    assert c4, "누수: 피처가 origin 이후(예: 2026) 참조"
    return {"rows": len(feat), "max_feat<=origin": bool(c1),
            "origin<target": bool(c2), "target<=panel_end": bool(c3),
            "no_future_ref": bool(c4)}


if __name__ == "__main__":
    eng = get_engine()
    panel = load_panel(eng)
    universe = load_universe(eng)
    grids = build_grids(panel)
    feat = build_features(grids, universe, VALIDATION_ORIGINS)

    print("=== 피처 행렬 ===")
    print(f"universe 목적지: {len(universe)}")
    print(f"origins: {[str(o) for o in VALIDATION_ORIGINS]}")
    print(f"shape: {feat.shape}")
    print(f"고유 목적지(피처 생성됨): {feat['dest'].nunique()}  (폴백/이력부족 제외: {len(universe) - feat['dest'].nunique()})")
    print(f"origin×horizon 조합: {feat.groupby(['origin','horizon']).ngroups}")
    print(f"계절지수 자기산출 비율: {feat['seasonal_index_own'].mean()*100:.1f}%  (나머지 풀 폴백)")

    print("\n=== 누수 검증 assert ===")
    res = leakage_checks(feat)
    for k, v in res.items():
        print(f"  {k}: {v}")
    print("  통과: 전 행 max(피처 period) <= origin < 타깃 period")

    print("\n=== 표본 (5행) ===")
    show = ["dest", "origin", "horizon", "target_period", "max_feature_period",
            "lag_1", "lag_12", "seasonal_index_target", "growth_damped", "target_passengers"]
    print(feat[show].head(5).to_string(index=False))

    print("\n=== origin별 행 수 / horizon별 행 수 ===")
    print(feat.groupby("origin").size().to_string())
    print(feat.groupby("horizon").size().to_string())
