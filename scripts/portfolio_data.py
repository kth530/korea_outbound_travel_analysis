"""Shared Excel-reading, source-integrity, and SQL helpers for the analysis."""
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
    """Standardize airport names before route facts are loaded to MySQL."""
    if pd.isna(value):
        return None
    name = re.sub(r"\([^)]*\)", "", str(value).strip())
    name = re.sub(r"[\s/_-]", "", name)
    return name or None


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
