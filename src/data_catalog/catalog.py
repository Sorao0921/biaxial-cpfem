from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import sqlite3
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Iterator

from src.config.pipeline_paths import ANALYSIS_DATABASE, PROJECT_ROOT

ROOT = PROJECT_ROOT
DEFAULT_DATABASE = ANALYSIS_DATABASE

CASE_RE = re.compile(
    r"(?P<texture>brass|copper|cube|goss|s)_(?:sd|sigma)(?P<sd>\d+)_seed(?P<seed>\d+)",
    re.IGNORECASE,
)
STATE_RE = re.compile(r"state(?P<state>\d+)", re.IGNORECASE)
RHO_RE = re.compile(r"(?:^|/)rho_(?P<rho>-?\d+(?:\.\d+)?)(?:/|$)")
SEED_RE = re.compile(r"(?:^|[_/])seed(?P<seed>\d+)(?:[_/.]|$)", re.IGNORECASE)

IGNORED_DIRS = {
    ".git",
    ".agents",
    ".mypy_cache",
    ".pytest_cache",
    "__pycache__",
    "node_modules",
    ".venv",
    "venv",
}


@dataclass(frozen=True)
class Classification:
    area: str
    data_kind: str
    stage: str
    representation: str
    role: str | None
    priority: int


@dataclass(frozen=True)
class CaseFields:
    rho: float | None
    seed: int | None
    texture: str | None
    sd: int | None
    state: int | None

    @property
    def complete(self) -> bool:
        return None not in (self.rho, self.seed, self.texture, self.sd, self.state)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def connect(database: Path) -> sqlite3.Connection:
    database.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(database)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    connection.execute("PRAGMA journal_mode = WAL")
    connection.execute("PRAGMA synchronous = NORMAL")
    return connection


SCHEMA = """
CREATE TABLE IF NOT EXISTS schema_info (
    version INTEGER NOT NULL,
    applied_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS scan_runs (
    scan_id INTEGER PRIMARY KEY,
    started_at TEXT NOT NULL,
    finished_at TEXT,
    root_path TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('running', 'complete', 'failed')),
    files_seen INTEGER NOT NULL DEFAULT 0,
    files_updated INTEGER NOT NULL DEFAULT 0,
    errors INTEGER NOT NULL DEFAULT 0,
    elapsed_seconds REAL
);

CREATE TABLE IF NOT EXISTS artifacts (
    artifact_id INTEGER PRIMARY KEY,
    absolute_path TEXT NOT NULL UNIQUE,
    relative_path TEXT NOT NULL,
    area TEXT NOT NULL,
    data_kind TEXT NOT NULL,
    stage TEXT NOT NULL,
    representation TEXT NOT NULL,
    extension TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    mtime_ns INTEGER NOT NULL,
    rho REAL,
    seed INTEGER,
    texture TEXT,
    sd INTEGER,
    state INTEGER,
    csv_columns_json TEXT,
    csv_header TEXT,
    sample_fingerprint TEXT,
    fingerprint_method TEXT,
    readable INTEGER NOT NULL DEFAULT 1,
    inspection_error TEXT,
    last_scan_id INTEGER NOT NULL REFERENCES scan_runs(scan_id)
);

CREATE INDEX IF NOT EXISTS idx_artifacts_case
    ON artifacts(rho, seed, texture, sd, state);
CREATE INDEX IF NOT EXISTS idx_artifacts_kind
    ON artifacts(data_kind, representation);
CREATE INDEX IF NOT EXISTS idx_artifacts_last_scan
    ON artifacts(last_scan_id);

CREATE TABLE IF NOT EXISTS cases (
    case_id INTEGER PRIMARY KEY,
    rho REAL NOT NULL,
    seed INTEGER NOT NULL,
    texture TEXT NOT NULL,
    sd INTEGER NOT NULL,
    state INTEGER NOT NULL,
    UNIQUE(rho, seed, texture, sd, state)
);

CREATE TABLE IF NOT EXISTS case_artifacts (
    case_id INTEGER NOT NULL REFERENCES cases(case_id) ON DELETE CASCADE,
    artifact_id INTEGER NOT NULL REFERENCES artifacts(artifact_id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    priority INTEGER NOT NULL,
    PRIMARY KEY(case_id, artifact_id, role)
);

CREATE INDEX IF NOT EXISTS idx_case_artifacts_role
    ON case_artifacts(role, priority);

CREATE VIEW IF NOT EXISTS v_theme1_case_readiness AS
SELECT
    c.case_id,
    c.rho,
    c.seed,
    c.texture,
    c.sd,
    c.state,
    MAX(CASE WHEN ca.role = 'surface_height' THEN 1 ELSE 0 END) AS has_surface_height,
    MAX(CASE WHEN ca.role = 'orientation_metrics' THEN 1 ELSE 0 END) AS has_orientation_metrics,
    MAX(CASE WHEN ca.role = 'accumulated_shear_strain' THEN 1 ELSE 0 END) AS has_accumulated_shear_strain,
    EXISTS(
        SELECT 1 FROM artifacts initial
        WHERE initial.data_kind = 'initial_orientation'
          AND initial.seed = c.seed
          AND initial.texture = c.texture
          AND initial.sd = c.sd
    ) AS has_initial_orientation,
    EXISTS(
        SELECT 1 FROM artifacts spatial
        WHERE spatial.data_kind = 'spatial_model_elements'
          AND spatial.seed = c.seed
    ) AS has_spatial_model,
    CASE WHEN
        MAX(CASE WHEN ca.role = 'surface_height' THEN 1 ELSE 0 END) = 1 AND
        MAX(CASE WHEN ca.role = 'orientation_metrics' THEN 1 ELSE 0 END) = 1 AND
        MAX(CASE WHEN ca.role = 'accumulated_shear_strain' THEN 1 ELSE 0 END) = 1
    THEN 1 ELSE 0 END AS theme1_ready,
    CASE WHEN
        MAX(CASE WHEN ca.role = 'surface_height' THEN 1 ELSE 0 END) = 1 AND
        MAX(CASE WHEN ca.role = 'orientation_metrics' THEN 1 ELSE 0 END) = 1 AND
        MAX(CASE WHEN ca.role = 'accumulated_shear_strain' THEN 1 ELSE 0 END) = 1 AND
        EXISTS(
            SELECT 1 FROM artifacts initial
            WHERE initial.data_kind = 'initial_orientation'
              AND initial.seed = c.seed
              AND initial.texture = c.texture
              AND initial.sd = c.sd
        ) AND
        EXISTS(
            SELECT 1 FROM artifacts spatial
            WHERE spatial.data_kind = 'spatial_model_elements'
              AND spatial.seed = c.seed
        )
    THEN 1 ELSE 0 END AS training_ready,
    COUNT(DISTINCT ca.artifact_id) AS artifact_count
FROM cases c
LEFT JOIN case_artifacts ca ON ca.case_id = c.case_id
GROUP BY c.case_id, c.rho, c.seed, c.texture, c.sd, c.state;

CREATE VIEW IF NOT EXISTS v_preferred_theme1_artifacts AS
SELECT
    c.rho,
    c.seed,
    c.texture,
    c.sd,
    c.state,
    ca.role,
    a.absolute_path,
    a.relative_path,
    a.data_kind,
    a.representation,
    a.size_bytes,
    ca.priority
FROM cases c
JOIN case_artifacts ca ON ca.case_id = c.case_id
JOIN artifacts a ON a.artifact_id = ca.artifact_id
WHERE ca.priority = (
    SELECT MIN(ca2.priority)
    FROM case_artifacts ca2
    WHERE ca2.case_id = ca.case_id AND ca2.role = ca.role
);
"""


def initialize(connection: sqlite3.Connection) -> None:
    connection.executescript(SCHEMA)
    row = connection.execute("SELECT MAX(version) AS version FROM schema_info").fetchone()
    if row["version"] is None:
        connection.execute(
            "INSERT INTO schema_info(version, applied_at) VALUES (?, ?)", (2, utc_now())
        )
    elif int(row["version"]) < 2:
        connection.executescript(
            "DROP VIEW IF EXISTS v_preferred_theme1_artifacts;"
            "DROP VIEW IF EXISTS v_theme1_case_readiness;"
        )
        # Re-run the idempotent schema after dropping the version-1 views.
        connection.executescript(SCHEMA)
        connection.execute(
            "INSERT INTO schema_info(version, applied_at) VALUES (?, ?)", (2, utc_now())
        )
    connection.commit()


def classify(relative_path: Path) -> Classification:
    value = relative_path.as_posix().lower()
    suffix = relative_path.suffix.lower()

    if "/coords/edge_dropped/" in f"/{value}":
        return Classification("outputs", "surface_height", "postprocess", "edge_dropped", "surface_height", 10)
    if "/coords/rawdata/" in f"/{value}":
        return Classification("outputs", "surface_height", "extracted", "raw", "surface_height", 20)
    if "/coords/roughness/" in f"/{value}":
        return Classification("outputs", "surface_roughness", "postprocess", "scalar_or_profile", "surface_roughness", 10)
    if "/coords/lines/" in f"/{value}":
        return Classification("outputs", "surface_profile", "postprocess", "line", "surface_profile", 10)
    if "/angles/grain_orientation_metrics/" in f"/{value}":
        return Classification("outputs", "grain_orientation_metrics", "postprocess", "grain_level", "orientation_metrics", 10)
    if "/angles/id_set/" in f"/{value}":
        return Classification("outputs", "orientation", "postprocess", "element_with_ids", "orientation", 20)
    if "/angles/rawdata/" in f"/{value}":
        return Classification("outputs", "orientation", "extracted", "raw", "orientation", 30)
    if "/shear_strains/id_set/" in f"/{value}":
        return Classification("outputs", "accumulated_shear_strain", "postprocess", "element_with_ids", "accumulated_shear_strain", 10)
    if "/shear_strains/rawdata/" in f"/{value}":
        return Classification("outputs", "accumulated_shear_strain", "extracted", "raw", "accumulated_shear_strain", 20)
    if value.startswith("inputs/orientation/") and suffix == ".csv":
        return Classification("inputs", "initial_orientation", "input", "grain_level", "initial_orientation", 10)
    if value.startswith("database/spatial_model/"):
        kind = relative_path.stem.lower()
        return Classification("database", f"spatial_model_{kind}", "reference", suffix.lstrip(".") or "file", "spatial_model", 10)
    if value.startswith("models/"):
        return Classification("models", "solver_model", "model", suffix.lstrip(".") or "file", None, 100)
    if "d3plot" in relative_path.name.lower():
        return Classification("solver", "solver_result", "solver", "d3plot", None, 100)
    if suffix in {".png", ".jpg", ".jpeg", ".svg", ".pdf"}:
        return Classification("derived", "figure_or_document", "derived", suffix.lstrip("."), None, 200)
    if suffix in {".py", ".m", ".ps1", ".sh", ".bat", ".tex", ".md"}:
        return Classification("code", "source_code", "source", suffix.lstrip("."), None, 200)
    return Classification(relative_path.parts[0] if relative_path.parts else "root", "other", "unknown", suffix.lstrip(".") or "no_extension", None, 500)


def parse_case(relative_path: Path) -> CaseFields:
    text = relative_path.as_posix()
    rho_match = RHO_RE.search(text)
    case_match = CASE_RE.search(text)
    # Some derived figures keep the target state in a parent directory (for
    # example ``state01_to_state13/gos_*.png``), not in the filename itself.
    # The final state token in the full path is consistently the target state.
    state_matches = list(STATE_RE.finditer(text))
    seed_match = SEED_RE.search(text)
    return CaseFields(
        rho=float(rho_match.group("rho")) if rho_match else None,
        seed=int(case_match.group("seed")) if case_match else (int(seed_match.group("seed")) if seed_match else None),
        texture=case_match.group("texture").lower() if case_match else None,
        sd=int(case_match.group("sd")) if case_match else None,
        state=int(state_matches[-1].group("state")) if state_matches else None,
    )


def iter_files(root: Path) -> Iterator[Path]:
    for directory, dirnames, filenames in os.walk(root):
        dirnames[:] = [name for name in dirnames if name not in IGNORED_DIRS]
        base = Path(directory)
        for filename in filenames:
            if filename == ".DS_Store":
                continue
            if filename.startswith("analysis.db-"):
                continue
            yield base / filename


def inspect_csv(path: Path) -> tuple[str | None, str | None, str | None]:
    try:
        with path.open("r", encoding="utf-8-sig", errors="replace", newline="") as stream:
            first_line = stream.readline(256 * 1024).rstrip("\r\n")
        if not first_line:
            return None, None, None
        dialect = csv.Sniffer().sniff(first_line, delimiters=",;\t ")
        values = next(csv.reader([first_line], dialect))
        columns = [value.strip() for value in values]
        is_header = any(re.search(r"[A-Za-z_]", value) for value in columns)
        return json.dumps(columns, ensure_ascii=False), first_line[:4000], "header" if is_header else "no_header"
    except Exception as exc:
        return None, None, f"{type(exc).__name__}: {exc}"


def sampled_fingerprint(path: Path, size: int, chunk_size: int = 65536) -> tuple[str | None, str | None, str | None]:
    try:
        digest = hashlib.sha256()
        digest.update(str(size).encode("ascii"))
        with path.open("rb") as stream:
            if size <= chunk_size * 3:
                digest.update(stream.read())
                method = "sha256_full"
            else:
                for offset in (0, max(0, size // 2 - chunk_size // 2), max(0, size - chunk_size)):
                    stream.seek(offset)
                    digest.update(stream.read(chunk_size))
                method = "sha256_sample_first_middle_last_64k"
        return digest.hexdigest(), method, None
    except Exception as exc:
        return None, None, f"{type(exc).__name__}: {exc}"


UPSERT_ARTIFACT = """
INSERT INTO artifacts(
    absolute_path, relative_path, area, data_kind, stage, representation,
    extension, size_bytes, mtime_ns, rho, seed, texture, sd, state,
    csv_columns_json, csv_header, sample_fingerprint, fingerprint_method,
    readable, inspection_error, last_scan_id
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(absolute_path) DO UPDATE SET
    relative_path=excluded.relative_path,
    area=excluded.area,
    data_kind=excluded.data_kind,
    stage=excluded.stage,
    representation=excluded.representation,
    extension=excluded.extension,
    size_bytes=excluded.size_bytes,
    mtime_ns=excluded.mtime_ns,
    rho=excluded.rho,
    seed=excluded.seed,
    texture=excluded.texture,
    sd=excluded.sd,
    state=excluded.state,
    csv_columns_json=excluded.csv_columns_json,
    csv_header=excluded.csv_header,
    sample_fingerprint=excluded.sample_fingerprint,
    fingerprint_method=excluded.fingerprint_method,
    readable=excluded.readable,
    inspection_error=excluded.inspection_error,
    last_scan_id=excluded.last_scan_id
RETURNING artifact_id;
"""


def existing_unchanged(connection: sqlite3.Connection, path: Path, size: int, mtime_ns: int) -> sqlite3.Row | None:
    return connection.execute(
        "SELECT artifact_id, size_bytes, mtime_ns, csv_columns_json, csv_header, sample_fingerprint, fingerprint_method, readable, inspection_error FROM artifacts WHERE absolute_path = ?",
        (str(path),),
    ).fetchone()


def ensure_case(connection: sqlite3.Connection, case: CaseFields) -> int:
    assert case.complete
    connection.execute(
        "INSERT OR IGNORE INTO cases(rho, seed, texture, sd, state) VALUES (?, ?, ?, ?, ?)",
        (case.rho, case.seed, case.texture, case.sd, case.state),
    )
    row = connection.execute(
        "SELECT case_id FROM cases WHERE rho = ? AND seed = ? AND texture = ? AND sd = ? AND state = ?",
        (case.rho, case.seed, case.texture, case.sd, case.state),
    ).fetchone()
    return int(row["case_id"])


def scan(root: Path, database: Path, *, fingerprint: bool = True, progress_every: int = 500) -> dict[str, int | float | str]:
    root = root.resolve()
    database = database.resolve()
    connection = connect(database)
    initialize(connection)
    started = time.monotonic()
    cursor = connection.execute(
        "INSERT INTO scan_runs(started_at, root_path, status) VALUES (?, ?, 'running')",
        (utc_now(), str(root)),
    )
    scan_id = int(cursor.lastrowid)
    connection.commit()
    seen = updated = errors = 0

    try:
        for path in iter_files(root):
            if path.resolve() == database:
                continue
            seen += 1
            try:
                stat = path.stat()
                relative = path.relative_to(root)
                classification = classify(relative)
                case = parse_case(relative)
                old = existing_unchanged(connection, path.resolve(), stat.st_size, stat.st_mtime_ns)
                unchanged = old is not None and old["size_bytes"] == stat.st_size and old["mtime_ns"] == stat.st_mtime_ns

                columns_json = old["csv_columns_json"] if unchanged else None
                csv_header = old["csv_header"] if unchanged else None
                sample_hash = old["sample_fingerprint"] if unchanged else None
                hash_method = old["fingerprint_method"] if unchanged else None
                readable = int(old["readable"]) if unchanged else 1
                problems: list[str] = []
                if unchanged and old["inspection_error"]:
                    problems.append(str(old["inspection_error"]))

                if not unchanged:
                    updated += 1
                    if path.suffix.lower() == ".csv":
                        columns_json, csv_header, csv_error = inspect_csv(path)
                        if csv_error and csv_error not in {"header", "no_header"}:
                            problems.append(csv_error)
                    if fingerprint:
                        sample_hash, hash_method, hash_error = sampled_fingerprint(path, stat.st_size)
                        if hash_error:
                            problems.append(hash_error)
                    if problems:
                        readable = 0

                artifact_id = int(connection.execute(
                    UPSERT_ARTIFACT,
                    (
                        str(path.resolve()), relative.as_posix(), classification.area,
                        classification.data_kind, classification.stage, classification.representation,
                        path.suffix.lower(), stat.st_size, stat.st_mtime_ns,
                        case.rho, case.seed, case.texture, case.sd, case.state,
                        columns_json, csv_header, sample_hash, hash_method,
                        readable, " | ".join(problems) or None, scan_id,
                    ),
                ).fetchone()[0])

                if classification.role and case.complete:
                    case_id = ensure_case(connection, case)
                    connection.execute(
                        "INSERT OR REPLACE INTO case_artifacts(case_id, artifact_id, role, priority) VALUES (?, ?, ?, ?)",
                        (case_id, artifact_id, classification.role, classification.priority),
                    )
            except Exception as exc:
                errors += 1
                print(f"warning: {path}: {type(exc).__name__}: {exc}", file=sys.stderr)

            if seen % progress_every == 0:
                connection.commit()
                elapsed = time.monotonic() - started
                print(f"catalog: {seen:,} files, {updated:,} updated, {errors:,} errors, {elapsed:.1f}s", flush=True)

        # Remove stale links and records only inside the root of this completed scan.
        stale_ids = [row[0] for row in connection.execute(
            "SELECT artifact_id FROM artifacts WHERE absolute_path LIKE ? AND last_scan_id <> ?",
            (str(root) + os.sep + "%", scan_id),
        )]
        if stale_ids:
            connection.executemany("DELETE FROM artifacts WHERE artifact_id = ?", ((value,) for value in stale_ids))
        connection.execute("DELETE FROM cases WHERE case_id NOT IN (SELECT DISTINCT case_id FROM case_artifacts)")
        elapsed = time.monotonic() - started
        connection.execute(
            "UPDATE scan_runs SET finished_at=?, status='complete', files_seen=?, files_updated=?, errors=?, elapsed_seconds=? WHERE scan_id=?",
            (utc_now(), seen, updated, errors, elapsed, scan_id),
        )
        connection.commit()
        return {"scan_id": scan_id, "files_seen": seen, "files_updated": updated, "errors": errors, "elapsed_seconds": round(elapsed, 3), "database": str(database)}
    except BaseException:
        elapsed = time.monotonic() - started
        connection.execute(
            "UPDATE scan_runs SET finished_at=?, status='failed', files_seen=?, files_updated=?, errors=?, elapsed_seconds=? WHERE scan_id=?",
            (utc_now(), seen, updated, errors + 1, elapsed, scan_id),
        )
        connection.commit()
        raise
    finally:
        connection.close()


def report(database: Path) -> dict[str, object]:
    connection = connect(database)
    initialize(connection)
    totals = dict(connection.execute(
        "SELECT COUNT(*) AS artifacts, COALESCE(SUM(size_bytes), 0) AS bytes, SUM(CASE WHEN readable = 0 THEN 1 ELSE 0 END) AS unreadable FROM artifacts"
    ).fetchone())
    readiness = dict(connection.execute(
        "SELECT COUNT(*) AS cases, COALESCE(SUM(theme1_ready), 0) AS core_ready, COALESCE(SUM(training_ready), 0) AS training_ready, COALESCE(SUM(has_surface_height), 0) AS height, COALESCE(SUM(has_orientation_metrics), 0) AS orientation, COALESCE(SUM(has_accumulated_shear_strain), 0) AS shear, COALESCE(SUM(has_initial_orientation), 0) AS initial_orientation, COALESCE(SUM(has_spatial_model), 0) AS spatial_model FROM v_theme1_case_readiness"
    ).fetchone())
    by_kind = [dict(row) for row in connection.execute(
        "SELECT data_kind, representation, COUNT(*) AS files, SUM(size_bytes) AS bytes FROM artifacts GROUP BY data_kind, representation ORDER BY files DESC"
    )]
    by_rho = [dict(row) for row in connection.execute(
        "SELECT rho, COUNT(*) AS cases, SUM(theme1_ready) AS ready FROM v_theme1_case_readiness GROUP BY rho ORDER BY rho"
    )]
    connection.close()
    return {"totals": totals, "theme1": readiness, "by_rho": by_rho, "by_kind": by_kind}


def export_manifest(database: Path, destination: Path, *, ready_only: bool) -> int:
    connection = connect(database)
    query = """
    WITH ranked AS (
        SELECT c.rho, c.seed, c.texture, c.sd, c.state, ca.role,
               a.absolute_path, a.relative_path, a.data_kind, a.representation,
               a.size_bytes, ca.priority,
               ROW_NUMBER() OVER (
                   PARTITION BY c.case_id, ca.role
                   ORDER BY ca.priority, a.relative_path
               ) AS choice
        FROM cases c
        JOIN case_artifacts ca ON ca.case_id = c.case_id
        JOIN artifacts a ON a.artifact_id = ca.artifact_id
        WHERE ca.role IN ('surface_height', 'orientation_metrics', 'accumulated_shear_strain')
    )
    SELECT p.rho, p.seed, p.texture, p.sd, p.state, p.role,
           p.absolute_path, p.relative_path, p.data_kind, p.representation,
           p.size_bytes, p.priority
    FROM ranked p
    JOIN v_theme1_case_readiness r
      ON r.rho=p.rho AND r.seed=p.seed AND r.texture=p.texture AND r.sd=p.sd AND r.state=p.state
    WHERE p.choice = 1
    """
    if ready_only:
        query += " AND r.training_ready = 1"
    query += " ORDER BY p.rho, p.seed, p.texture, p.sd, p.state, p.role"
    rows = connection.execute(query).fetchall()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(rows[0].keys() if rows else ["rho", "seed", "texture", "sd", "state", "role", "absolute_path", "relative_path", "data_kind", "representation", "size_bytes", "priority"])
        writer.writerows(tuple(row) for row in rows)
    connection.close()
    return len(rows)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build and query the MFPL research-data catalog.")
    parser.add_argument("--database", type=Path, default=DEFAULT_DATABASE)
    subparsers = parser.add_subparsers(dest="command", required=True)
    scan_parser = subparsers.add_parser("scan", help="Incrementally scan the pipeline directory.")
    scan_parser.add_argument("--root", type=Path, default=ROOT)
    scan_parser.add_argument("--no-fingerprint", action="store_true")
    scan_parser.add_argument("--progress-every", type=int, default=500)
    subparsers.add_parser("report", help="Print catalog and Theme 1 readiness statistics.")
    export_parser = subparsers.add_parser("export", help="Export preferred Theme 1 artifacts as CSV.")
    export_parser.add_argument("destination", type=Path)
    export_parser.add_argument("--all-cases", action="store_true")
    return parser


def main(argv: Iterable[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "scan":
        result = scan(args.root, args.database, fingerprint=not args.no_fingerprint, progress_every=args.progress_every)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    elif args.command == "report":
        print(json.dumps(report(args.database), ensure_ascii=False, indent=2))
    elif args.command == "export":
        count = export_manifest(args.database, args.destination, ready_only=not args.all_cases)
        print(json.dumps({"rows": count, "destination": str(args.destination)}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
