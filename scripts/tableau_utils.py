"""Tableau 출력에서 사용하는 목적지 표시명·국가·지역 보조 함수."""

from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
DESTINATION_REFERENCE = ROOT / "config" / "05_destination_region_map.csv"


DISPLAY_NAME_MAP = {
    "간사이": "오사카 간사이",
    "도쿄나리타": "도쿄 나리타",
    "도쿄하네다": "도쿄 하네다",
    "삿보로": "삿포로",
    "타이페이": "타이베이",
    "따이쭝": "타이중",
    "카오슝": "가오슝",
    "푸동": "상하이 푸둥",
    "북경": "베이징",
    "청도": "칭다오",
    "대련": "다롄",
    "센젠": "선전",
    "심양": "선양",
    "연길": "옌지",
    "연대": "옌타이",
    "천진": "톈진",
    "항조우": "항저우",
    "오끼나와": "오키나와",
    "구마모도": "구마모토",
    "카고시마": "가고시마",
    "다가마스": "다카마쓰",
    "싱가폴": "싱가포르",
    "나트랑캄란": "나트랑 깜라인",
    "런던히드로": "런던 히드로",
    "뱅쿠버": "밴쿠버",
    "아틀란타": "애틀랜타",
}


def destination_reference() -> pd.DataFrame:
    """DB 목적지명과 대시보드 표시명·국가·지역을 1행으로 반환한다."""
    reference = pd.read_csv(DESTINATION_REFERENCE)
    reference = reference.rename(
        columns={
            "destination_canonical_std": "목적지_DB",
            "country": "국가",
            "region": "지역",
        }
    )
    reference["목적지"] = reference["목적지_DB"].replace(DISPLAY_NAME_MAP)
    return reference[["목적지_DB", "목적지", "국가", "지역"]]


def add_destination_labels(df: pd.DataFrame, source_col: str) -> pd.DataFrame:
    """목적지 키를 보존하면서 Tableau용 표시명·국가·지역을 붙인다."""
    result = df.copy()
    result["목적지_DB"] = result[source_col]
    result["목적지"] = result[source_col].replace(DISPLAY_NAME_MAP)
    result = result.merge(destination_reference(), on="목적지_DB", how="left", suffixes=("", "_ref"), validate="m:1")
    result["목적지"] = result["목적지_ref"].fillna(result["목적지"])
    result = result.drop(columns=["목적지_ref"])
    result["국가"] = result["국가"].fillna("미분류")
    result["지역"] = result["지역"].fillna("미분류")
    return result
