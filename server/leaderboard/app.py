"""A small, client-trusting leaderboard. Player IDs are identifiers, not credentials."""

from contextlib import asynccontextmanager, contextmanager
from datetime import datetime, timezone
import hashlib
import os
from pathlib import Path
import sqlite3
from typing import Annotated, Literal
import unicodedata
from uuid import UUID

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request, Response
from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, StrictInt, field_validator


RULESET = "la-52w-v1"
MAX_BODY = 8_192
MAX_JSON_INT = 9_007_199_254_740_991


def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


@contextmanager
def database(path):
    connection = sqlite3.connect(path, timeout=10)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    try:
        with connection:
            yield connection
    finally:
        connection.close()


def initialize(path):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with database(path) as db:
        db.execute("PRAGMA journal_mode = WAL")
        version = db.execute("PRAGMA user_version").fetchone()[0]
        if version not in (0, 1, 2):
            raise RuntimeError(f"Unsupported database version: {version}")
        db.executescript("""
            CREATE TABLE IF NOT EXISTS players (
                player_key TEXT PRIMARY KEY,
                display_name TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS runs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ruleset TEXT NOT NULL,
                run_id TEXT NOT NULL,
                player_key TEXT NOT NULL REFERENCES players(player_key),
                net_worth INTEGER NOT NULL,
                profile_id INTEGER NOT NULL,
                health INTEGER NOT NULL,
                experience_count INTEGER NOT NULL,
                used_purchases INTEGER NOT NULL,
                completed_at TEXT NOT NULL,
                received_at TEXT NOT NULL,
                app_version TEXT NOT NULL,
                fingerprint TEXT NOT NULL,
                UNIQUE(ruleset, run_id)
            );
            CREATE INDEX IF NOT EXISTS runs_player_best
                ON runs(ruleset, player_key, net_worth DESC, id);
            CREATE INDEX IF NOT EXISTS runs_world_ranking
                ON runs(ruleset, net_worth DESC, id);
        """)
        if "ending" not in {row[1] for row in db.execute("PRAGMA table_info(runs)")}:
            db.execute("ALTER TABLE runs ADD COLUMN ending TEXT NOT NULL DEFAULT 'deported'")
        db.execute("PRAGMA user_version = 2")


# One best run per iCloud identity across all three local Profile slots.
# Equal scores are ordered by the first successful server submission.
RANKED = """
    WITH personal AS (
        SELECT *, ROW_NUMBER() OVER (
            PARTITION BY player_key ORDER BY net_worth DESC, id
        ) AS personal_position
        FROM runs WHERE ruleset = ?
    ), ranked AS (
        SELECT *, ROW_NUMBER() OVER (ORDER BY net_worth DESC, id) AS rank
        FROM personal WHERE personal_position = 1
    )
"""


class Nickname(BaseModel):
    model_config = ConfigDict(extra="forbid")
    display_name: str = Field(min_length=1, max_length=24)

    @field_validator("display_name")
    @classmethod
    def clean_name(cls, value):
        value = unicodedata.normalize("NFC", value).strip()
        if not value or any(unicodedata.category(char).startswith("C") for char in value):
            raise ValueError("Use a visible nickname without control characters")
        return value


class RunSubmission(Nickname):
    run_id: UUID
    ruleset: Literal["la-52w-v1"] = RULESET
    net_worth: StrictInt = Field(ge=-MAX_JSON_INT, le=MAX_JSON_INT)
    profile_id: StrictInt = Field(ge=1, le=3)
    weeks_survived: Literal[52]
    ending: Literal["deported", "rooted"]
    health: StrictInt = Field(ge=1, le=100)
    experience_count: StrictInt = Field(ge=0, le=MAX_JSON_INT)
    used_purchases: bool = Field(strict=True)
    completed_at: AwareDatetime
    app_version: str = Field(min_length=1, max_length=64)


def player_key(value: str):
    # Keep the original hash namespace for existing IDs, including local test IDs.
    # Raw player identifiers are neither stored nor returned on the public board.
    return hashlib.sha256(("survive-in-la:cloudkit:" + value).encode()).hexdigest()


def parse_identity(value):
    if value is None:
        return None
    if not 1 <= len(value) <= 256 or any(ord(c) < 33 or ord(c) > 126 for c in value):
        raise HTTPException(400, "Invalid X-Player-ID")
    return player_key(value)


def optional_identity(x_player_id: Annotated[str | None, Header()] = None):
    return parse_identity(x_player_id)


def required_identity(key=Depends(optional_identity)):
    if key is None:
        raise HTTPException(400, "X-Player-ID is required")
    return key


def public_run(row, key):
    return {
        "run_id": row["run_id"],
        "display_name": row["display_name"],
        "net_worth": row["net_worth"],
        "profile_id": row["profile_id"],
        "health": row["health"],
        "experience_count": row["experience_count"],
        "used_purchases": bool(row["used_purchases"]),
        "completed_at": row["completed_at"],
        "received_at": row["received_at"],
        "app_version": row["app_version"],
        "ending": row["ending"],
        "is_me": row["player_key"] == key,
    }


def best_for_player(db, key):
    row = db.execute(RANKED + """
        SELECT ranked.*, players.display_name FROM ranked
        JOIN players USING(player_key) WHERE player_key = ?
    """, (RULESET, key)).fetchone()
    return {**public_run(row, key), "rank": row["rank"]} if row else None


def create_app(db_path=None):
    path = str(db_path or os.environ.get("DATABASE_PATH", "/data/leaderboard.sqlite3"))

    @asynccontextmanager
    async def lifespan(app):
        initialize(path)
        yield

    app = FastAPI(title="Surviving LA Leaderboard", version="1.0.0", lifespan=lifespan)

    @app.middleware("http")
    async def limit_body(request: Request, call_next):
        # Bound actual bytes too; Content-Length is optional and not trusted.
        payload = bytearray()
        async for chunk in request.stream():
            payload.extend(chunk)
            if len(payload) > MAX_BODY:
                return Response(status_code=413)
        request._body = bytes(payload)
        response = await call_next(request)
        # Personalized is_me / my_best must never leak through a shared cache.
        response.headers["Cache-Control"] = "no-store"
        return response

    @app.exception_handler(sqlite3.OperationalError)
    async def database_unavailable(request, error):
        import logging
        logging.exception("Leaderboard database unavailable", exc_info=error)
        return Response(status_code=503, headers={"Retry-After": "10"})

    @app.get("/healthz")
    def health():
        with database(path) as db:
            db.execute("SELECT 1 FROM runs LIMIT 1").fetchone()
        return {"status": "ok", "ruleset": RULESET}

    @app.put("/v1/player")
    def rename(body: Nickname, key=Depends(required_identity)):
        with database(path) as db:
            db.execute("""
                INSERT INTO players VALUES (?, ?)
                ON CONFLICT(player_key) DO UPDATE SET display_name=excluded.display_name
            """, (key, body.display_name))
        return {"display_name": body.display_name}

    @app.post("/v1/runs")
    def submit(body: RunSubmission, response: Response, key=Depends(required_identity)):
        # A nickname is mutable; retries of an immutable run can carry an older name.
        canonical = body.model_dump_json(exclude={"display_name"})
        fingerprint = hashlib.sha256(canonical.encode()).hexdigest()
        with database(path) as db:
            db.execute("BEGIN IMMEDIATE")
            previous = db.execute("""
                SELECT player_key, fingerprint FROM runs WHERE ruleset=? AND run_id=?
            """, (RULESET, str(body.run_id))).fetchone()
            duplicate = previous is not None
            if previous and (previous["player_key"] != key or previous["fingerprint"] != fingerprint):
                raise HTTPException(409, "This run ID already has a different submission")
            if not duplicate:
                db.execute("INSERT OR IGNORE INTO players VALUES (?, ?)", (key, body.display_name))
                db.execute("""
                    INSERT INTO runs (
                        ruleset, run_id, player_key, net_worth, profile_id, health,
                        experience_count, used_purchases, completed_at, received_at,
                        app_version, fingerprint, ending
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    RULESET, str(body.run_id), key, body.net_worth, body.profile_id,
                    body.health, body.experience_count, body.used_purchases,
                    body.completed_at.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
                    utc_now(), body.app_version, fingerprint, body.ending,
                ))
            best = best_for_player(db, key)
            total = db.execute("SELECT COUNT(DISTINCT player_key) FROM runs WHERE ruleset=?", (RULESET,)).fetchone()[0]
        response.status_code = 200 if duplicate else 201
        return {
            "run_id": str(body.run_id), "duplicate": duplicate,
            "is_personal_best": best["run_id"] == str(body.run_id),
            "my_best": best, "total_players": total, "as_of": utc_now(),
        }

    @app.get("/v1/leaderboard")
    def leaderboard(
        limit: Annotated[int, Query(ge=1, le=100)] = 100,
        key=Depends(optional_identity),
    ):
        with database(path) as db:
            # A consistent read snapshot across entries, counts and my_best.
            db.execute("BEGIN")
            rows = db.execute(RANKED + """
                SELECT ranked.*, players.display_name FROM ranked
                JOIN players USING(player_key) ORDER BY rank LIMIT ?
            """, (RULESET, limit)).fetchall()
            counts = db.execute("""
                SELECT COUNT(*) AS runs, COUNT(DISTINCT player_key) AS players
                FROM runs WHERE ruleset=?
            """, (RULESET,)).fetchone()
            best = best_for_player(db, key) if key else None
        return {
            "ruleset": RULESET, "as_of": utc_now(),
            "total_players": counts["players"], "total_runs": counts["runs"],
            "entries": [{**public_run(row, key), "rank": row["rank"]} for row in rows],
            "my_best": best,
        }

    @app.get("/v1/rankings")
    def rankings(limit: Annotated[int, Query(ge=1, le=50)] = 50):
        # Rank submitted runs, including multiple completed saves from one player.
        with database(path) as db:
            db.execute("BEGIN")
            rows = db.execute("""
                SELECT runs.*, players.display_name FROM runs JOIN players USING(player_key)
                WHERE ruleset=? ORDER BY net_worth DESC, id LIMIT ?
            """, (RULESET, limit)).fetchall()
            counts = db.execute("""
                SELECT COUNT(*) AS runs, COUNT(DISTINCT player_key) AS players
                FROM runs WHERE ruleset=?
            """, (RULESET,)).fetchone()
        return {
            "ruleset": RULESET, "as_of": utc_now(),
            "total_runs": counts["runs"], "total_players": counts["players"],
            "entries": [{**public_run(row, None), "rank": i + 1} for i, row in enumerate(rows)],
        }

    @app.get("/v1/me/runs")
    def history(
        limit: Annotated[int, Query(ge=1, le=100)] = 20,
        before: Annotated[int | None, Query(ge=1)] = None,
        key=Depends(required_identity),
    ):
        with database(path) as db:
            rows = db.execute("""
                SELECT runs.*, players.display_name FROM runs JOIN players USING(player_key)
                WHERE ruleset=? AND player_key=? AND (? IS NULL OR id < ?)
                ORDER BY id DESC LIMIT ?
            """, (RULESET, key, before, before, limit + 1)).fetchall()
        page = rows[:limit]
        return {
            "entries": [public_run(row, key) for row in page],
            "next_before": page[-1]["id"] if len(rows) > limit else None,
        }

    return app


app = create_app()
