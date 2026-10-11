"""Compare B1 and Ridge demand on the same 2026-07 destination-month panel.

B1 uses prior-year actual monthly demand and as-of-origin growth factors.
No Test observation or Ridge prediction enters the B1 calculation.
"""
from pathlib import Path
import argparse
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
EXPLORATORY = {"따이쭝", "히로시마", "시즈오카"}


def summarize(frame: pd.DataFrame, label: str) -> pd.DataFrame:
    d = frame.groupby("목적지_DB", as_index=False).agg(
        목적지=("목적지", "first"), 국가=("국가", "first"), 지역=("지역", "first"),
        인기순위=("2025_인기순위", "first"), 전년수요=("전년동월실제수요", "sum"),
        예측수요=("예측수요", "sum"), 성장계수=("성장계수", "first"),
        표본구간=("표본구간", "first"), 성수월=("성수월", "first"),
    )
    d["예상증가인원"] = d["예측수요"] - d["전년수요"]
    d["예상증가율"] = np.where(d["전년수요"] > 0, d["예상증가인원"] / d["전년수요"], np.nan)
    d["증가예상월수"] = frame.assign(up=frame["예측수요"] > frame["전년동월실제수요"]).groupby("목적지_DB")["up"].sum().reindex(d["목적지_DB"]).to_numpy()
    peak = frame.sort_values(["목적지_DB", "예측수요", "월"], ascending=[True, False, True]).drop_duplicates("목적지_DB")
    d["추천월"] = d["목적지_DB"].map(peak.set_index("목적지_DB")["월"])
    popular = d["인기순위"] <= 20
    growth = (~popular & d["표본구간"].isin(["ge36", "24_35"])
              & (d["전년수요"] >= 30000) & (d["예측수요"] >= 50000)
              & (d["성장계수"] > 1) & (d["예상증가인원"] > 0)
              & (d["증가예상월수"] >= 3))
    d = d[popular | growth].copy()
    d["후보구분"] = np.where(d["인기순위"] <= 20, "기존 인기", "성장 후보")
    d["검토트랙"] = np.select(
        [(d["인기순위"] <= 20) & (d["예상증가인원"] < 0),
         (d["인기순위"] <= 20), d["목적지_DB"].isin(EXPLORATORY)],
        ["방어", "인기", "탐색"], default="성장")
    d["모델"] = label
    d["후보순위"] = 0
    for group, sort_col in [("기존 인기", "예측수요"), ("성장 후보", "예상증가인원")]:
        mask = d["후보구분"] == group
        order = d.loc[mask].sort_values([sort_col, "목적지_DB"], ascending=[False, True])
        d.loc[order.index, "후보순위"] = np.arange(1, len(order) + 1)
    return d.sort_values(["후보구분", "후보순위"])


def build(source: Path | pd.DataFrame, output: Path,
          archived_candidates: Path | pd.DataFrame | None = None) -> dict:
    ridge = source.copy() if isinstance(source, pd.DataFrame) else pd.read_csv(source, encoding="utf-8-sig")
    ridge["예측기준일"] = pd.to_datetime(ridge["예측기준일"]).dt.strftime("%Y-%m-%d")
    keys = ["목적지_DB", "예측월"]
    assert len(ridge) == 845 and not ridge.duplicated(keys).any()
    assert ridge["예측기준일"].eq("2026-07-01").all()
    assert set(ridge["월"]) == {8, 9, 10, 11, 12}
    assert ridge.groupby("목적지_DB").size().eq(5).all()
    assert ridge["성장계수"].groupby(ridge["목적지_DB"]).nunique().eq(1).all()
    assert np.isclose(ridge["예측수요"].sum(), 20416998, atol=1)

    base = ridge.drop(columns=["2025_상태지연율", "2025_취소율"], errors="ignore").copy()
    base["모델"] = "B1 전년동월×성장"
    base["예측수요"] = base["전년동월실제수요"] * base["성장계수"]
    base["예상증가인원"] = base["예측수요"] - base["전년동월실제수요"]
    base["예상증가율"] = np.where(
        base["전년동월실제수요"] > 0,
        base["예상증가인원"] / base["전년동월실제수요"], np.nan)
    base["월예측비중"] = base["예측수요"] / base.groupby("예측월")["예측수요"].transform("sum")
    # Ridge validation residual quantiles are not valid B1 intervals.
    base = base.drop(columns=["예측하한", "예측상한", "검증WAPE"], errors="ignore")
    assert np.isclose(base["예측수요"].sum(), 21241512, atol=2)

    b1 = summarize(base, "B1 전년동월×성장")
    old = summarize(ridge, "B1+Ridge 잔차보정 (비교안)")
    b1_popular = set(b1.loc[b1["후보구분"] == "기존 인기", "목적지_DB"])
    b1_growth = set(b1.loc[b1["후보구분"] == "성장 후보", "목적지_DB"])
    base["후보구분"] = np.select(
        [base["목적지_DB"].isin(b1_popular), base["목적지_DB"].isin(b1_growth)],
        ["기존 인기", "성장 후보"], default="기타 모델링 목적지")
    if isinstance(archived_candidates, pd.DataFrame):
        archived = archived_candidates.copy()
    else:
        archived_path = archived_candidates or ROOT / "tableau/promotion_candidates.csv"
        archived = pd.read_csv(archived_path, encoding="utf-8-sig")
    assert set(old["목적지_DB"]) == set(archived["목적지_DB"])
    assert np.allclose(old.set_index("목적지_DB").loc[archived["목적지_DB"], "예측수요"], archived["2026_8_12_예측수요"])

    cols = ["목적지_DB", "목적지", "후보구분", "검토트랙", "후보순위", "추천월", "예측수요", "예상증가인원", "예상증가율"]
    comparison = old[cols].merge(b1[cols], on="목적지_DB", how="outer", suffixes=("_Ridge", "_B1"), indicator=True)
    comparison["후보변화"] = comparison["_merge"].map({"both": "공통", "left_only": "Ridge만", "right_only": "B1 신규"})
    comparison["순위변화_B1빼기Ridge"] = comparison["후보순위_B1"] - comparison["후보순위_Ridge"]
    comparison["추천월변화"] = comparison["추천월_B1"].fillna(-1).ne(comparison["추천월_Ridge"].fillna(-1))
    comparison["트랙변화"] = comparison["검토트랙_B1"].fillna("없음").ne(comparison["검토트랙_Ridge"].fillna("없음"))
    output.mkdir(parents=True, exist_ok=True)
    base.to_csv(output / "forecast_destination_monthly_b1.csv", index=False, encoding="utf-8-sig")
    b1.to_csv(output / "promotion_candidates_b1.csv", index=False, encoding="utf-8-sig")
    comparison.drop(columns="_merge").to_csv(output / "candidate_comparison_b1_ridge.csv", index=False, encoding="utf-8-sig")
    return {"b1": b1, "ridge": old, "comparison": comparison}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=ROOT / "tableau/forecast_destination_monthly.csv")
    parser.add_argument("--output", type=Path, default=ROOT / "tableau")
    args = parser.parse_args()
    result = build(args.source, args.output)
    for name, df in result.items():
        print(name, len(df), "rows")
    print("B1 total", round(pd.read_csv(args.output / "forecast_destination_monthly_b1.csv")["예측수요"].sum()))
