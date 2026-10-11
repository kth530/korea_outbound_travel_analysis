"""Shared, idempotent source and SQL helpers for the five portfolio files."""
from __future__ import annotations

import hashlib
import os
import re
import warnings
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

ROOT = Path(__file__).resolve().parents[1]


def sql_root() -> Path:
    return Path(os.environ.get("PORTFOLIO_SQL_DIR", ROOT / "sql"))


def get_engine():
    load_dotenv(ROOT / ".env")
    db = dict(host=os.getenv("DB_HOST"), port=int(os.getenv("DB_PORT", "3306")),
              database=os.getenv("DB_NAME"), username=os.getenv("DB_USER"),
              password=os.getenv("DB_PASSWORD"))
    missing = [k for k in ("host", "database", "username", "password") if not db[k]]
    if missing:
        raise ValueError(f"Missing .env DB settings: {missing}")
    return create_engine(URL.create("mysql+pymysql", **db), pool_pre_ping=True, future=True)


def named_sql(filename: str) -> dict[str, str]:
    source = (sql_root() / filename).read_text(encoding="utf-8")
    matches = list(re.finditer(r"^-- name: ([a-z0-9_]+)\s*$", source, flags=re.MULTILINE))
    return {match.group(1): source[match.end():matches[i + 1].start()
            if i + 1 < len(matches) else len(source)].strip().rstrip(";")
            for i, match in enumerate(matches)}


def apply_ddl(engine, sql: dict[str, str], names: list[str]) -> None:
    with engine.begin() as connection:
        for name in names:
            connection.execute(text(sql[name]))


def query(engine, sql: dict[str, str], name: str) -> pd.DataFrame:
    return pd.read_sql(text(sql[name]), engine)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalize_airport_name(value: object) -> str | None:
    """Match the airport-name key used by the route views in sql/02 and sql/00b."""
    if pd.isna(value):
        return None
    name = re.sub(r"\([^)]*\)", "", str(value).strip())
    name = re.sub(r"[\s/_-]", "", name)
    return name or None


def source_period(path: Path, flight_log: bool = False) -> tuple[int, int | None]:
    match = re.search(r"(20\d{2})(?:[_-](0?[1-9]|1[0-2]))?", path.stem)
    if not match:
        raise ValueError(f"No year/month in {path.name}")
    return int(match.group(1)), int(match.group(2)) if flight_log and match.group(2) else None


def prepare_frame(path: Path, dataset: dict) -> pd.DataFrame:
    with warnings.catch_warnings():
        warnings.filterwarnings("ignore", message="Workbook contains no default style.*")
        source = pd.read_excel(path, dtype=object)
    missing = set(dataset["columns"]) - set(source.columns)
    if missing:
        raise ValueError(f"{path.name} missing columns: {sorted(missing)}")
    frame = source.loc[:, dataset["columns"]].rename(columns=dataset["rename"]).copy()
    for column in frame:
        if column in {"passengers", "operations"}:
            frame[column] = pd.to_numeric(frame[column], errors="raise")
        else:
            frame[column] = frame[column].map(lambda value: None if pd.isna(value) else str(value).strip())
    return frame


def source_manifest(source_root: Path, datasets: list[dict]) -> pd.DataFrame:
    return pd.DataFrame([{"target_table": d["target"], "file_count": len(list(source_root.glob(d["pattern"]))) }
                         for d in datasets])


def load_files(engine, source_root: Path, datasets: list[dict], pipeline_name: str) -> pd.DataFrame:
    """Skip matching files by hash; refuse changed files and commit each file atomically."""
    with engine.begin() as connection:
        batch_id = connection.execute(text(
            "INSERT INTO meta_load_batch (pipeline_name, source_root, status) "
            "VALUES (:pipeline, :root, 'running')"),
            {"pipeline": pipeline_name, "root": source_root.as_posix()}).lastrowid
    results = []
    try:
        for dataset in datasets:
            for path in sorted(source_root.glob(dataset["pattern"])):
                target = dataset["target"]
                source_file = path.relative_to(ROOT).as_posix()
                digest = file_sha256(path)
                with engine.connect() as connection:
                    existing = connection.execute(text(
                        "SELECT source_sha256, status FROM meta_load_file "
                        "WHERE source_file=:source_file AND target_table=:target"),
                        {"source_file": source_file, "target": target}).mappings().first()
                if existing and existing["status"] == "loaded":
                    if existing["source_sha256"] != digest:
                        raise RuntimeError(f"Already loaded source changed: {source_file}")
                    results.append({"target_table": target, "result": "skipped", "rows": 0})
                    continue
                frame = prepare_frame(path, dataset)
                year, month = source_period(path, target.startswith("raw_departure_flight"))
                with engine.begin() as connection:
                    frame.to_sql(target, connection, if_exists="append", index=False,
                                 chunksize=5000, method="multi")
                    connection.execute(text(
                        "INSERT INTO meta_load_file "
                        "(source_file,target_table,source_sha256,source_year,source_month,"
                        "source_rows,loaded_rows,batch_id,status) "
                        "VALUES (:source_file,:target,:digest,:year,:month,:rows,:rows,:batch_id,'loaded')"),
                        {"source_file": source_file, "target": target, "digest": digest,
                         "year": year, "month": month, "rows": len(frame), "batch_id": batch_id})
                results.append({"target_table": target, "result": "loaded", "rows": len(frame)})
    except Exception as error:
        with engine.begin() as connection:
            connection.execute(text("UPDATE meta_load_batch SET status='failed', "
                                    "completed_at=CURRENT_TIMESTAMP,note=:note WHERE batch_id=:batch_id"),
                               {"note": str(error)[:1000], "batch_id": batch_id})
        raise
    with engine.begin() as connection:
        connection.execute(text("UPDATE meta_load_batch SET status='loaded', "
                                "completed_at=CURRENT_TIMESTAMP WHERE batch_id=:batch_id"),
                           {"batch_id": batch_id})
    return pd.DataFrame(results)
