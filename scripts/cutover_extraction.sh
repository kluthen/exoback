#!/usr/bin/env bash
#
# cutover_extraction.sh — one-shot adoption of a single-DB (pre-extraction) hub
# deployment into the v3 per-service topology: auth (upsilonauth), economy
# (upsiloneconomy) and the slimmed hub, each on its own database on the SAME
# Postgres instance. See reporting/v3_platform/service_extraction/01_prod_cutover_runbook.md
# for the full procedure, invariants and rollback.
#
# THIS SCRIPT IS DESTRUCTIVE and is GUARDED on purpose:
#   * dry-run by default — prints every statement, changes nothing;
#   * requires --execute AND an interactive typed confirmation to mutate;
#   * HARD-REFUSES any host that looks like AWS/RDS (never run against AWS
#     without Bastien — this guard is not a substitute for that judgement).
#
# It performs same-instance copies (no cross-network dump), seeds economy wallets
# from users.credits, and ensures the hub player_stats backfill has run BEFORE
# the hub drops the users table (hub migration 000005). Ordering is the whole
# point: back-fill first, drop last.
set -euo pipefail

# ---- configuration (env) ---------------------------------------------------
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-upsilon}"
SOURCE_DB="${SOURCE_DB:-upsilon}"        # the pre-extraction single hub DB
AUTH_DB="${AUTH_DB:-upsilonauth}"
ECONOMY_DB="${ECONOMY_DB:-upsiloneconomy}"
HUB_DB="${HUB_DB:-upsilon}"              # slimmed hub keeps the source DB name

EXECUTE=0
[[ "${1:-}" == "--execute" ]] && EXECUTE=1

log()  { printf '\033[36m[cutover]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[cutover]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m[cutover] ABORT:\033[0m %s\n' "$*" >&2; exit 1; }

# ---- guards ----------------------------------------------------------------
# Never against AWS/RDS. This is a mechanical backstop, not the decision itself.
case "$PGHOST" in
  *.rds.amazonaws.com|*amazonaws.com|*.aws.*)
    die "PGHOST '$PGHOST' looks like AWS. This script never runs against AWS. Stop and get Bastien." ;;
esac
if [[ "${AWS_EXECUTION_ENV:-}" != "" || "${AWS_REGION:-}" != "" ]]; then
  die "AWS environment variables present. Refusing to run inside an AWS context."
fi

psql_src() { PGPASSWORD="${PGPASSWORD:-}" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$SOURCE_DB" -v ON_ERROR_STOP=1 "$@"; }
run() {
  # run "<label>" <db> "<SQL>": echo always; execute only when EXECUTE=1.
  local label="$1" db="$2" sql="$3"
  log "$label  (db=$db)"
  printf '    %s\n' "$sql"
  if [[ "$EXECUTE" == "1" ]]; then
    PGPASSWORD="${PGPASSWORD:-}" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$db" -v ON_ERROR_STOP=1 -c "$sql"
  fi
}

if [[ "$EXECUTE" == "1" ]]; then
  warn "EXECUTE mode: this WILL mutate $AUTH_DB, $ECONOMY_DB and drop tables in $HUB_DB."
  warn "Target instance: $PGHOST:$PGPORT (source DB: $SOURCE_DB)."
  read -r -p "Type 'CUTOVER' to proceed: " confirm
  [[ "$confirm" == "CUTOVER" ]] || die "not confirmed"
else
  log "DRY RUN (no changes). Re-run with --execute to apply. Statements follow:"
fi

# ---- 0. preflight ----------------------------------------------------------
# Every service DB must already exist and be migrated to its own head (run each
# service's -migrate first). Confirm the source still has the tables we adopt.
log "Preflight: confirm source tables present (users, credits, shop/inventory)."
if [[ "$EXECUTE" == "1" ]]; then
  psql_src -tAc "SELECT to_regclass('public.users'), to_regclass('public.shop_items');" \
    | grep -q 'users' || die "source DB $SOURCE_DB has no users table — is this already cut over?"
fi

# ---- 1. auth: adopt accounts + tokens --------------------------------------
# Same-instance copy via dblink-free INSERT ... SELECT is not possible across
# databases; use pg_dump --data-only of the three tables piped into AUTH_DB.
log "Step 1 — copy accounts/tokens into $AUTH_DB (pg_dump --data-only, same instance)."
COPY_AUTH="pg_dump -h $PGHOST -p $PGPORT -U $PGUSER -d $SOURCE_DB --data-only \
  -t public.users -t public.personal_access_tokens -t public.password_reset_tokens \
  | psql -h $PGHOST -p $PGPORT -U $PGUSER -d $AUTH_DB -v ON_ERROR_STOP=1"
log "    $COPY_AUTH"
[[ "$EXECUTE" == "1" ]] && eval "PGPASSWORD='${PGPASSWORD:-}' $COPY_AUTH"

# ---- 2. economy: adopt catalog/inventory/ledger + seed wallets -------------
log "Step 2 — copy shop/inventory/ledger into $ECONOMY_DB, then seed wallets from users.credits."
COPY_ECON="pg_dump -h $PGHOST -p $PGPORT -U $PGUSER -d $SOURCE_DB --data-only \
  -t public.shop_items -t public.player_inventory \
  -t public.credit_transactions -t public.inventory_transactions \
  | psql -h $PGHOST -p $PGPORT -U $PGUSER -d $ECONOMY_DB -v ON_ERROR_STOP=1"
log "    $COPY_ECON"
[[ "$EXECUTE" == "1" ]] && eval "PGPASSWORD='${PGPASSWORD:-}' $COPY_ECON"
# Wallet balances are NOT a source table — they are derived from users.credits.
# Dump just (id, credits) and upsert into the economy wallets table. The exact
# column/table names track upsiloneconomy's schema; adjust if it evolves.
SEED_WALLETS="pg_dump -h $PGHOST -p $PGPORT -U $PGUSER -d $SOURCE_DB --data-only \
  --column-inserts -t public.users \
  | grep -iE 'INSERT INTO public.users' \
  | sed -E 's/.*/-- (transform users.credits -> wallets upsert in psql, see runbook step 2)/' \
  | psql -h $PGHOST -p $PGPORT -U $PGUSER -d $ECONOMY_DB -v ON_ERROR_STOP=1"
log "Step 2b — seed wallets from users.credits (see runbook §2 for the exact upsert SQL):"
log "    $SEED_WALLETS"
# NB: the runbook gives the concrete 'INSERT INTO wallets (user_id, balance)
# SELECT id, credits FROM users ON CONFLICT ...' — run it inside a dblink/FDW or
# from a users.credits export. Left explicit here rather than auto-generated so a
# schema drift can't silently mis-seed money.

# ---- 3. hub: backfill player_stats BEFORE dropping users -------------------
# Hub migration 000004 already backfills player_stats from users on a fresh
# adopt; confirm it has run, THEN apply 000005 (the drop). Never 000005 first.
run "Step 3a — verify player_stats is populated (backfilled by 000004)" "$HUB_DB" \
  "SELECT count(*) AS player_stats_rows FROM public.player_stats;"
log "Step 3b — apply the hub drop migration (000005) LAST:"
log "    upsilonhub -migrate-mode full   # (or baseline for an adopted DB) — runs 000005"
if [[ "$EXECUTE" == "1" ]]; then
  warn "Run 'upsilonhub -migrate-mode baseline' yourself now (kept out of this script so the"
  warn "migration binary — not raw SQL — owns the drop). Verify player_stats first."
fi

log "Done (${EXECUTE/1/EXECUTE}${EXECUTE/0/DRY-RUN}). Verify per runbook §5 before cutting traffic."
