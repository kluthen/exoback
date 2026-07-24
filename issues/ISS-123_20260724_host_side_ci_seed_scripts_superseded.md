# Issue: host-side CI seed/trigger scripts assume a single hub-owned DB — superseded by the 6-image compose stack

**ID:** `20260724_host_side_ci_seed_scripts_superseded`
**Ref:** `ISS-123`
**Date:** 2026-07-24
**Severity:** Medium
**Status:** Open
**Component:** `scripts/` (seed_ci.sh, trigger_all_ci_tests.sh, trigger_quick_ci_tests.sh, run_ci_local.sh, start_services.sh, setup_prod.sh)
**Affects:** the host-side (non-docker) dev/CI convenience path; the authoritative `docker-compose.ci.yaml` stack is unaffected

---

## Summary

`scripts/seed_ci.sh` resets **one** database (`$DATABASE_URL`), runs
`upsilonhub -migrate-mode full`, then `upsilonhub -seed` expecting it to seed
"catalog, testuser, admins". After the v3 extraction this is wrong on two counts:

- **Accounts + shop catalog no longer live in the hub.** Post-Phase-3/4/5,
  `upsilonhub -seed` seeds only the skill-template catalog; testuser/admin/dummy
  accounts are seeded by `upsilonauth -seed` (its own DB) and the shop catalog by
  `upsiloneconomy -seed` (its own DB). So `seed_ci.sh` produces a hub DB with no
  accounts, and its `ADMIN_INITIAL_PASSWORD` gate is now a no-op.
- **Single-DB assumption.** The extracted world is three databases on the shared
  Postgres (`upsilon`, `upsilonauth`, `upsiloneconomy`), each migrated/seeded by
  its own binary. A one-`DATABASE_URL` script structurally cannot seed the stack.

`seed_ci.sh` is invoked by `trigger_all_ci_tests.sh:37` and
`trigger_quick_ci_tests.sh:37`; `run_ci_local.sh`, `start_services.sh` and
`setup_prod.sh` reference the same single-DB seeding assumptions. These predate
the extraction and were quietly superseded by `docker-compose.ci.yaml`, whose
per-service `*-migrate` / `*-seed` init containers are the real, green CI gate
(the 6-image stack passes the full scenario suite). The host-side path was not
re-cut when the services moved out.

## Impact

Anyone running the host-side scripts (rather than the compose stack) gets a hub
DB with no accounts and no shop catalog → E2E login/admin/shop flows fail. No
production impact (there is none), and the merge gate is unaffected. This is
stale-tooling debt, surfaced during the Phase-5 table-drop work (the agent
flagged it when `-seed` stopped touching `users`/`shop_items`).

## Fix options (pick one, coordinated)

1. **Retire** the host-side single-DB scripts and standardize dev + local CI on
   `docker compose -f docker-compose.ci.yaml` (what CI already does). Simplest;
   removes a whole parallel, drifting path.
2. **Re-cut** them for the multi-service world: each script provisions the three
   DBs and runs each service's own migrate+seed. More surface to maintain.

Also drop the now no-op `ADMIN_INITIAL_PASSWORD` env from the `hub-seed` service
in `docker-compose.ci.yaml` (harmless, but it narrates the retired behavior).

## Not urgent

The authoritative CI path is green; this is developer-ergonomics + honesty debt.
Do NOT rush a rewrite into the Phase-5 landing — track and schedule.
