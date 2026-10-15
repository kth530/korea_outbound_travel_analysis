"""Read eight route Excel files and build analytic tables before loading MySQL.

Source files stay unchanged. The pipeline checks their published monthly totals,
standardizes airport and month keys, separates international routes, and creates
destination-month facts and the static destination profile.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import text

try:
    from . import portfolio_data as pdx
except ImportError:  # direct script execution
    import portfolio_data as pdx


ROOT = Path(__file__).resolve().parents[1]
ROUTE_KEYS = ["origin_airport_raw", "destination_airport_raw", "period_raw"]
ROUTE_COLUMNS = [
    *ROUTE_KEYS, "period_ym", "passengers", "operations",
    "origin_airport_std", "destination_airport_std",
    "route_scope_std", "is_international",
]
METRICS = {
    "passenger": ("여객(명)", "passengers"),
    "operations": ("운항(편)", "operations"),
}
SOURCES = {
    "2023_2025": ROOT / "data/raw/airportal",
    "2026": ROOT / "data/raw_2026/airportal",
}
EXPECTED_SOURCE_ROWS = {
    "2023_2025": {"passenger": 9670, "operations": 9670},
    "2026": {"passenger": 2079, "operations": 2079},
}


def _read_metric(source_root: Path, metric: str) -> pd.DataFrame:
    excel_name, value_name = METRICS[metric]
    files = sorted(source_root.glob(
        f"transport_statistics/route/route_{metric}_*.xlsx"))
    expected_files = 3 if source_root == SOURCES["2023_2025"] else 1
    if len(files) != expected_files:
        raise FileNotFoundError(
            f"Expected {expected_files} {metric} files under {source_root}; got {len(files)}")
    dataset = {
        "columns": ["노선1", "노선2", "년월", excel_name],
        "rename": {"노선1": ROUTE_KEYS[0], "노선2": ROUTE_KEYS[1],
                   "년월": ROUTE_KEYS[2], excel_name: value_name},
    }
    frame = pd.concat([pdx.prepare_frame(path, dataset) for path in files],
                      ignore_index=True)
    if frame[ROUTE_KEYS].duplicated().any():
        raise ValueError(f"Duplicate {metric} route-month keys")
    if frame[ROUTE_KEYS[:1] + ROUTE_KEYS[2:]].isna().any().any():
        raise ValueError(f"Missing {metric} origin or period")
    return frame


def _check_reported_totals(frame: pd.DataFrame, value_col: str) -> None:
    aggregate = frame[frame["origin_airport_raw"].eq("전체 합계")]
    detail = frame[frame["origin_airport_raw"].ne("전체 합계")]
    if aggregate["period_raw"].duplicated().any():
        raise ValueError(f"Duplicate {value_col} monthly total")
    reported = aggregate.set_index("period_raw")[value_col].sort_index()
    summed = detail.groupby("period_raw")[value_col].sum().sort_index()
    pd.testing.assert_series_equal(reported, summed, check_names=False)


def _period_ym(raw: pd.Series) -> pd.Series:
    parts = raw.astype("string").str.extract(r"^([0-9]{4})년\s*([0-9]{1,2})월$")
    month = pd.to_numeric(parts[1], errors="coerce")
    valid = month.between(1, 12)
    if not valid.all():
        raise ValueError(f"Invalid period rows: {raw[~valid].head().tolist()}")
    return parts[0] + month.astype("int64").astype(str).str.zfill(2)


def _domestic_reference() -> pd.DataFrame:
    reference = pd.read_csv(ROOT / "config/domestic_airports.csv", dtype=str)
    if reference["destination_std"].duplicated().any():
        raise ValueError("Duplicate domestic airport reference")
    return reference


def transform_routes(source_root: Path) -> pd.DataFrame:
    passenger = _read_metric(source_root, "passenger")
    operations = _read_metric(source_root, "operations")
    period_group = "2023_2025" if source_root == SOURCES["2023_2025"] else "2026"
    for metric, frame in (("passenger", passenger), ("operations", operations)):
        if len(frame) != EXPECTED_SOURCE_ROWS[period_group][metric]:
            raise AssertionError(f"Unexpected {metric} source rows: {len(frame)}")
        _check_reported_totals(frame, METRICS[metric][1])

    passenger = passenger[passenger["origin_airport_raw"].ne("전체 합계")]
    operations = operations[operations["origin_airport_raw"].ne("전체 합계")]
    result = passenger.merge(operations, on=ROUTE_KEYS, how="outer",
                             validate="one_to_one", sort=False, indicator=True)
    if not result["_merge"].eq("both").all():
        raise ValueError("Passenger and operation route-month keys differ")
    result = result.drop(columns="_merge")
    result["period_ym"] = _period_ym(result["period_raw"])
    for raw, standard in (("origin_airport_raw", "origin_airport_std"),
                          ("destination_airport_raw", "destination_airport_std")):
        result[standard] = result[raw].map(pdx.normalize_airport_name)

    domestic = set(_domestic_reference()["destination_std"])
    origin_domestic = result["origin_airport_std"].isin(domestic)
    destination_domestic = result["destination_airport_std"].isin(domestic)
    missing_name = (result["origin_airport_std"].isna()
                    | result["destination_airport_std"].isna())
    result["route_scope_std"] = np.select(
        [missing_name, origin_domestic & destination_domestic,
         origin_domestic & ~destination_domestic],
        ["unresolved", "domestic", "international"],
        default="unresolved",
    )
    result["is_international"] = result["route_scope_std"].map(
        {"domestic": 0, "international": 1}).astype("Int64")
    result = result[ROUTE_COLUMNS].sort_values(ROUTE_KEYS).reset_index(drop=True)
    expected = 9634 if period_group == "2023_2025" else 2072
    if len(result) != expected:
        raise AssertionError(f"Unexpected detailed route rows: {len(result)}")
    return result


def transform_destination_monthly(*routes: pd.DataFrame) -> pd.DataFrame:
    combined = pd.concat(routes, ignore_index=True)
    international = combined[combined["is_international"].eq(1)].copy()
    international["active_origin"] = international["origin_airport_std"].where(
        international["passengers"].fillna(0).gt(0)
        | international["operations"].fillna(0).gt(0))
    panel = (international
             .groupby(["period_ym", "destination_airport_std"], sort=True)
             .agg(passengers=("passengers", "sum"),
                  operations=("operations", "sum"),
                  origin_airport_count=("active_origin", "nunique"))
             .reset_index()
             .rename(columns={"destination_airport_std":
                              "destination_canonical_std"}))
    for column in ("passengers", "operations", "origin_airport_count"):
        panel[column] = panel[column].astype("int64")
    if len(panel) != 7825 or panel["destination_canonical_std"].nunique() != 286:
        raise AssertionError("Destination-month panel signature changed")
    return panel


def transform_destination_profile(panel: pd.DataFrame) -> pd.DataFrame:
    """Static destination eligibility and descriptive season labels."""
    records = []
    for destination, group in panel.groupby("destination_canonical_std", sort=True):
        year = group["period_ym"].str[:4]
        month = group["period_ym"].str[4:]

        def quarter_sum(selected_year: str, months: tuple[str, ...]) -> int | None:
            rows = group.loc[year.eq(selected_year) & month.isin(months), "passengers"]
            return int(rows.sum()) if len(rows) else None

        q1_2024 = quarter_sum("2024", ("01", "02", "03"))
        q2_2024 = quarter_sum("2024", ("04", "05", "06"))
        q1_2025 = quarter_sum("2025", ("01", "02", "03"))
        q2_2025 = quarter_sum("2025", ("04", "05", "06"))

        def seasonal_label(q1: int | None, q2: int | None) -> str | None:
            if q1 is None or q2 is None:
                return None
            if q1 > q2 * 1.05:
                return "winter"
            if q2 > q1 * 1.05:
                return "summer"
            return "flat"

        months_present = len(group)
        records.append({
            "destination_canonical_std": destination,
            "first_period": group["period_ym"].min(),
            "last_period": group["period_ym"].max(),
            "months_present": months_present,
            "months_positive": int(group["passengers"].gt(0).sum()),
            **{f"months_{y}": int(year.eq(str(y)).sum()) for y in range(2023, 2027)},
            "total_passengers": int(group["passengers"].sum()),
            "q1_2024": q1_2024, "q2_2024": q2_2024,
            "q1_2025": q1_2025, "q2_2025": q2_2025,
            "sample_band": ("ge36" if months_present >= 36 else
                            "24_35" if months_present >= 24 else
                            "12_23" if months_present >= 12 else "lt12"),
            "in_modeling_universe": int(months_present >= 24),
            "seasonal_label_2024": seasonal_label(q1_2024, q2_2024),
            "seasonal_label_2025": seasonal_label(q1_2025, q2_2025),
        })
    profile = pd.DataFrame.from_records(records)
    if len(profile) != 286 or int(profile["in_modeling_universe"].sum()) != 169:
        raise AssertionError("Destination eligibility signature changed")
    return profile


def build() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    early = transform_routes(SOURCES["2023_2025"])
    holdout = transform_routes(SOURCES["2026"])
    panel = transform_destination_monthly(early, holdout)
    profile = transform_destination_profile(panel)
    return _domestic_reference(), early, holdout, panel, profile


def _load_table(connection, name: str, frame: pd.DataFrame) -> None:
    connection.execute(text(f"DELETE FROM `{name}`"))
    frame.to_sql(name, connection, if_exists="append", index=False,
                 chunksize=1000, method="multi")


def load_etl_tables(engine, frames: tuple[pd.DataFrame, ...]) -> None:
    ddl = (ROOT / "sql/00_etl_pipeline.sql").read_text(encoding="utf-8")
    ddl = "\n".join(line for line in ddl.splitlines()
                    if not line.strip().startswith("--"))
    with engine.begin() as connection:
        for statement in ddl.split(";"):
            if statement.strip():
                connection.execute(text(statement))
    with engine.begin() as connection:
        for name, frame in zip(
            ("etl_domestic_airport_reference", "etl_route_monthly_2023_2025",
             "etl_route_monthly_2026", "etl_destination_monthly_all",
             "etl_destination_profile"), frames
        ):
            _load_table(connection, name, frame)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--load", action="store_true",
                        help="Load the five ETL tables into MySQL")
    args = parser.parse_args()
    frames = build()
    for name, frame in zip(("domestic_reference", "routes_2023_2025",
                            "routes_2026", "destination_monthly",
                            "destination_profile"), frames):
        print(name, len(frame))
    if args.load:
        load_etl_tables(pdx.get_engine(), frames)
        print("ETL tables loaded")


if __name__ == "__main__":
    main()
