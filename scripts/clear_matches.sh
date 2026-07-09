#!/usr/bin/env bash
cd "$(dirname "$0")/.."
# Clear ghost matches (and stranded queue entries, see ISS-104) from the database

echo "Clearing matches..."
psql "${DATABASE_URL:?DATABASE_URL is mandatory}" -q <<'SQL'
TRUNCATE table game_matches CASCADE;
TRUNCATE table match_participants CASCADE;
TRUNCATE table matchmaking_queues;
SQL
echo "Done!"
