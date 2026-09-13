FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 DATABASE_PATH=/data/leaderboard.sqlite3
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt \
    && groupadd --gid 10001 leaderboard \
    && useradd --uid 10001 --gid leaderboard --no-create-home leaderboard \
    && mkdir /data && chown leaderboard:leaderboard /data
COPY app.py backup.py ./
USER leaderboard
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--limit-concurrency", "64", "--timeout-keep-alive", "5", "--no-access-log"]
