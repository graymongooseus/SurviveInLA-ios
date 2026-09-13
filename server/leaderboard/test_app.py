from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest
from uuid import uuid4

from fastapi.testclient import TestClient

from app import create_app, initialize, MAX_BODY


class LeaderboardTests(unittest.TestCase):
    def setUp(self):
        self.directory = TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "scores.sqlite3"
        self.client = self.enterContext(TestClient(create_app(self.path)))

    def payload(self, score=25_000, **changes):
        return {
            "run_id": str(uuid4()), "display_name": "洛城旅人4821",
            "ruleset": "la-52w-v1", "net_worth": score, "profile_id": 1,
            "weeks_survived": 52, "ending": "deported", "health": 38,
            "experience_count": 12, "used_purchases": False,
            "completed_at": "2026-09-04T20:00:00Z", "app_version": "0.2",
            **changes,
        }

    def submit(self, player="_cloudkit-player-a", body=None, **changes):
        return self.client.post("/v1/runs", headers={"X-Player-ID": player}, json=body or self.payload(**changes))

    def board(self, player="_cloudkit-player-a", **params):
        return self.client.get("/v1/leaderboard", headers={"X-Player-ID": player}, params=params).json()

    def test_empty_board_and_health(self):
        self.assertEqual(self.client.get("/healthz").status_code, 200)
        board = self.board()
        self.assertEqual((board["total_runs"], board["total_players"], board["entries"], board["my_best"]), (0, 0, [], None))

    def test_local_test_identity_rooted_ending_and_retries(self):
        body = self.payload(ending="rooted", app_version="1.1 (2)")
        self.assertEqual(self.submit("test-device-123", body=body).status_code, 201)
        self.assertEqual(self.submit("test-device-123", body=body).status_code, 200)
        entries = self.client.get("/v1/rankings").json()["entries"]
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["ending"], "rooted")
        self.assertEqual(entries[0]["app_version"], "1.1 (2)")

    def test_version_one_migration_retains_records_and_duplicate_fingerprints(self):
        body = self.payload()
        self.assertEqual(self.submit(body=body).status_code, 201)
        with sqlite3.connect(self.path) as db:
            db.execute("ALTER TABLE runs DROP COLUMN ending")
            db.execute("PRAGMA user_version = 1")
        initialize(self.path)
        initialize(self.path)
        self.assertEqual(self.submit(body=body).status_code, 200)
        self.assertEqual(self.client.get("/v1/rankings").json()["entries"][0]["ending"], "deported")
        with sqlite3.connect(self.path) as db:
            self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 2)

    def test_all_runs_saved_but_best_across_profiles_only(self):
        self.assertEqual(self.submit(score=10).status_code, 201)
        self.submit(score=30, profile_id=2)
        result = self.submit(score=20, profile_id=3).json()
        self.assertFalse(result["is_personal_best"])
        board = self.board()
        self.assertEqual((board["total_runs"], board["total_players"]), (3, 1))
        self.assertEqual(board["my_best"]["net_worth"], 30)
        self.assertEqual(board["entries"][0]["profile_id"], 2)

    def test_ties_use_first_server_receipt_and_negative_scores_are_valid(self):
        self.submit("a", score=10, completed_at="2026-09-04T20:00:00Z")
        self.submit("b", score=10, completed_at="2000-01-01T00:00:00Z")
        self.submit("c", score=-50)
        entries = self.board("b")["entries"]
        self.assertEqual([e["rank"] for e in entries], [1, 2, 3])
        self.assertTrue(entries[1]["is_me"])
        self.assertEqual(entries[2]["net_worth"], -50)

    def test_duplicate_is_idempotent_and_conflict_does_not_overwrite(self):
        body = self.payload()
        self.assertEqual(self.submit(body=body).status_code, 201)
        duplicate = self.submit(body=body)
        self.assertEqual(duplicate.status_code, 200)
        self.assertTrue(duplicate.json()["duplicate"])
        self.assertEqual(self.submit(body={**body, "net_worth": 99}).status_code, 409)
        self.assertEqual(self.submit("another-account", body=body).status_code, 409)
        self.assertEqual(self.board()["total_runs"], 1)

    def test_concurrent_retries_insert_one_run(self):
        body = self.payload()
        with ThreadPoolExecutor(max_workers=6) as pool:
            responses = list(pool.map(lambda _: self.submit(body=body).status_code, range(6)))
        self.assertEqual(sorted(responses), [200, 200, 200, 200, 200, 201])
        self.assertEqual(self.board()["total_runs"], 1)

    def test_my_rank_available_outside_top_100(self):
        for number in range(101):
            self.submit(f"player-{number}", score=number)
        board = self.board("player-0")
        self.assertEqual(len(board["entries"]), 100)
        self.assertEqual(board["my_best"]["rank"], 101)

    def test_public_board_never_discloses_player_id_or_fingerprint(self):
        self.submit()
        response = self.client.get("/v1/leaderboard")
        for private_field in ("_cloudkit-player-a", "player_key", "fingerprint"):
            self.assertNotIn(private_field, response.text)
        self.assertIsNone(response.json()["my_best"])
        self.assertFalse(response.json()["entries"][0]["is_me"])
        self.assertEqual(response.headers["cache-control"], "no-store")

    def test_rename_survives_retry_and_stale_new_submission(self):
        body = self.payload()
        self.submit(body=body)
        response = self.client.put("/v1/player", headers={"X-Player-ID": "_cloudkit-player-a"}, json={"display_name": " 新昵称 "})
        self.assertEqual(response.status_code, 200)
        self.submit(body=body)
        self.submit(score=30_000)
        self.assertEqual(self.board()["entries"][0]["display_name"], "新昵称")

    def test_invalid_structure_and_non_final_runs_rejected(self):
        for changes in (
            {"net_worth": True}, {"net_worth": 2.5}, {"net_worth": "400"},
            {"net_worth": 10**30}, {"ending": "dead"}, {"weeks_survived": 40},
            {"health": 0}, {"display_name": " \n "}, {"display_name": "a\x00b"},
            {"profile_id": 4}, {"completed_at": "2026-09-04T12:00:00"},
            {"ruleset": "unknown"}, {"used_purchases": "false"},
        ):
            with self.subTest(changes=changes):
                self.assertEqual(self.submit(**changes).status_code, 422)
        self.assertEqual(self.client.post("/v1/runs", json=self.payload()).status_code, 400)
        self.assertEqual(self.board()["total_runs"], 0)

    def test_high_client_score_is_trusted_without_replay(self):
        response = self.submit(score=8_000_000_000_000, used_purchases=True)
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["my_best"]["net_worth"], 8_000_000_000_000)

    def test_history_cursor_stays_stable_when_new_runs_arrive(self):
        for number in range(5):
            self.submit(score=number)
        headers = {"X-Player-ID": "_cloudkit-player-a"}
        first = self.client.get("/v1/me/runs?limit=2", headers=headers).json()
        self.assertEqual([e["net_worth"] for e in first["entries"]], [4, 3])
        self.submit(score=5)
        second = self.client.get("/v1/me/runs", headers=headers, params={"limit": 2, "before": first["next_before"]}).json()
        self.assertEqual([e["net_worth"] for e in second["entries"]], [2, 1])
        other = self.client.get("/v1/me/runs", headers={"X-Player-ID": "other"}).json()
        self.assertEqual(other["entries"], [])

    def test_payload_and_query_bounds(self):
        self.assertEqual(self.client.post("/v1/runs", content=b"x" * (MAX_BODY + 1)).status_code, 413)
        for query in ("limit=0", "limit=101", "limit=foo"):
            self.assertEqual(self.client.get("/v1/leaderboard?" + query).status_code, 422)
        self.assertEqual(self.client.get("/v1/me/runs").status_code, 400)

    def test_restart_and_online_backup_preserve_records(self):
        self.submit(score=999)
        with TestClient(create_app(self.path)) as reopened:
            self.assertEqual(reopened.get("/v1/leaderboard").json()["total_runs"], 1)
        result = subprocess.run(
            [sys.executable, str(Path(__file__).with_name("backup.py"))],
            env={**os.environ, "DATABASE_PATH": str(self.path)}, capture_output=True, check=True,
        )
        backup = Path(self.directory.name) / "backup.sqlite3"
        backup.write_bytes(result.stdout)
        with sqlite3.connect(backup) as db:
            self.assertEqual(db.execute("PRAGMA integrity_check").fetchone()[0], "ok")
            self.assertEqual(db.execute("SELECT net_worth FROM runs").fetchone()[0], 999)
        # Also boot the API from the restored backup, not only inspect SQLite.
        with TestClient(create_app(backup)) as restored:
            self.assertEqual(restored.get("/v1/leaderboard").json()["entries"][0]["net_worth"], 999)

    def test_world_top50_ranks_each_submitted_save_with_its_version(self):
        first = self.payload(score=200, profile_id=1, app_version="1.0 (2)")
        second = self.payload(score=100, profile_id=2, app_version="1.1 (5)")
        self.submit(body=first)
        self.submit(body=second)
        self.submit("other", score=150, display_name="另一个旅人", app_version="1.1 (6)")
        board = self.client.get("/v1/rankings").json()
        self.assertEqual((board["total_runs"], board["total_players"]), (3, 2))
        self.assertEqual([e["net_worth"] for e in board["entries"]], [200, 150, 100])
        self.assertEqual([e["app_version"] for e in board["entries"]], ["1.0 (2)", "1.1 (6)", "1.1 (5)"])
        self.assertEqual(board["entries"][0]["display_name"], first["display_name"])
        self.assertEqual(board["entries"][2]["profile_id"], 2)
        self.assertEqual(len(self.board()["entries"]), 2)  # Existing personal-best API stays compatible.

    def test_world_top50_limit_order_and_no_fake_rows(self):
        empty = self.client.get("/v1/rankings").json()
        self.assertEqual(empty["entries"], [])
        ids = []
        for number in range(55):
            body = self.payload(score=100, app_version="1.1")
            ids.append(body["run_id"])
            self.submit(body=body)
        board = self.client.get("/v1/rankings").json()
        self.assertEqual(board["total_runs"], 55)
        self.assertEqual([e["run_id"] for e in board["entries"]], ids[:50])
        self.assertEqual([e["rank"] for e in board["entries"]], list(range(1, 51)))
        self.assertEqual(self.client.get("/v1/rankings?limit=51").status_code, 422)
        self.assertEqual(self.client.get("/v1/rankings?limit=0").status_code, 422)


if __name__ == "__main__":
    unittest.main()
