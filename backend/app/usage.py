from datetime import datetime, timezone
from pathlib import Path
import sqlite3


class MonthlyUsageLedger:
    def __init__(self, database_path: str) -> None:
        self.database_path = Path(database_path)

    def reserve(self, provider: str, limit: int) -> bool:
        if limit < 1:
            return False
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        period = datetime.now(timezone.utc).strftime("%Y-%m")
        with sqlite3.connect(self.database_path, timeout=5) as connection:
            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS monthly_usage (
                    period TEXT NOT NULL,
                    provider TEXT NOT NULL,
                    request_count INTEGER NOT NULL,
                    PRIMARY KEY (period, provider)
                )
                """
            )
            connection.execute("BEGIN IMMEDIATE")
            row = connection.execute(
                "SELECT request_count FROM monthly_usage WHERE period = ? AND provider = ?",
                (period, provider),
            ).fetchone()
            request_count = int(row[0]) if row else 0
            if request_count >= limit:
                connection.rollback()
                return False
            connection.execute(
                """
                INSERT INTO monthly_usage (period, provider, request_count)
                VALUES (?, ?, 1)
                ON CONFLICT(period, provider)
                DO UPDATE SET request_count = request_count + 1
                """,
                (period, provider),
            )
            connection.commit()
        return True
