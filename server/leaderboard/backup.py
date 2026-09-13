"""Stream a consistent SQLite online backup to stdout, including WAL changes."""
import os
from pathlib import Path
import sqlite3
import sys
import tempfile


source_path = Path(os.environ.get("DATABASE_PATH", "/data/leaderboard.sqlite3"))
with tempfile.TemporaryDirectory(prefix=".backup-", dir=source_path.parent) as directory:
    target = Path(directory) / "backup.sqlite3"
    source = sqlite3.connect(source_path.resolve().as_uri() + "?mode=ro", uri=True)
    destination = sqlite3.connect(target)
    try:
        source.backup(destination)
        if destination.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise RuntimeError("Backup integrity check failed")
    finally:
        destination.close()
        source.close()
    with target.open("rb") as stream:
        while chunk := stream.read(65_536):
            sys.stdout.buffer.write(chunk)
