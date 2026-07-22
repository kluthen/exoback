-- create_databases.sql — per-service database provisioning on the shared Postgres instance.
-- Mounted at /docker-entrypoint-initdb.d/ so it runs on first cluster init (fresh volume / CI tmpfs).
-- NOTE: initdb scripts do NOT run on an existing dev volume — run `docker compose down -v` to reprovision.
-- Idempotent: \gexec only creates what is missing, so this file is also safe to pipe through psql manually
-- (the prod cutover runbook does exactly that).
--
-- One database per service (relocatable to a dedicated instance later — never cross-database SQL):
--   upsilon        — upsilonhub (gameplay, characters, matches, player_stats)
--   upsilonauth    — upsilonauth (users auth columns, personal_access_tokens)
--   upsiloneconomy — upsiloneconomy (wallets, ledgers, shop, inventory)

SELECT 'CREATE DATABASE upsilon'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'upsilon')\gexec

SELECT 'CREATE DATABASE upsilonauth'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'upsilonauth')\gexec

SELECT 'CREATE DATABASE upsiloneconomy'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'upsiloneconomy')\gexec
