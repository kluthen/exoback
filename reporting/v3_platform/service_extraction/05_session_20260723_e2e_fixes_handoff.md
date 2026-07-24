# Session 2026-07-23 (part 2) — handoff: CI-stack E2E run + regression fixes (RC3 REMAINS)

Continues `04_session_20260723_handoff.md` (READ IT for the Phase-4 cutover design + the
"what shipped in session 2" background). This doc executes 04 §4 step 1 (boot the 6-image CI
stack, prove register→login→enroll→play) and captures what the E2E run exposed.

**Interrupted mid-flight:** the auth agent working the last regression (RC3) hit the monthly
spend limit (04 §6's known gotcha) before writing any RC3 code. Resume from §4 below.

> **UPDATE 2026-07-24 — RC3 DONE + suite green (§7 below).** RC3 landed (auth `df97531`), a
> second latent bug in the same scenario surfaced behind it and was fixed (RC3b, cli `5b34ab7`),
> full CI-stack suite is **34/3** (the 3 = ISS-119 race family + ISS-103, all intermittent).
> Umbrella atomic land was staged and is awaiting Bastien's go-ahead. See §7.

## 1. What this session did

1. Booted the 6-image CI stack (`docker compose -f docker-compose.ci.yaml up -d --build --wait`)
   — all services healthy. Ran the full `tests/run_all_scenarios.sh`.
2. First run: **28 passed / 9 failed.** Triaged all 9 (see §2). Found **3 real Phase-4
   regressions** (2 root causes at first, a 3rd surfaced after those were fixed); the other 6
   are pre-existing dev-machine reds (ISS-119 match-start race + ISS-103 privacy) or confirmed
   flakes of that same async family.
3. Fixed 2 of the 3 regressions (RC1, RC2), rebuilt, re-ran: **31 passed / 6 failed** — which
   exposed the 3rd regression (RC3) hiding behind RC2.
4. RC3 fix was dispatched to the auth agent but **not completed** (spend limit).

## 2. The 9 original failures — full disposition

| Scenario | Verdict | Notes |
|---|---|---|
| `e2e_customer_login` | **RC1 — FIXED** | register→login→GET /profile w/o enroll → hub `getProfile` panicked 500 on `playerstats.ErrNotFound` |
| `e2e_admin_full_lifecycle` | **RC2 — FIXED** | admin `/users` returned `{users}` not `{items,has_more,next_cursor}`; the `admin_dashboard` line is a non-fatal try/catch, ignore it |
| `e2e_admin_user_management` | **RC3 — NOT FIXED** | got past `items` fix, now fails at `admin_user_anonymize: Invalid user id` — see §4 |
| `e2e_battle_starts_privacy_check` | known red | ISS-103 (foe-loadout masking never implemented); not a regression |
| `e2e_match_resolution_forfeit` | known red | ISS-119 async match-start race (forfeit before engine game-start) |
| `e2e_progression_post_win_with_2` | known red | ISS-119 race |
| `e2e_match_resolution_standard_with_2` | flake (race) | ISS-119; passed on re-run |
| `e2e_exotic_weapon_dual_path` | flake | passed on re-run (board-state timing) |
| `e2e_friendly_fire_prevention` | flake | passed twice on re-run (matchmaking timing) |

After RC1+RC2, the 6 remaining reds were: `admin_user_management` (RC3), the 3 known ISS-119/103
reds above, plus 2 new flakes that were green in run 1:
- `e2e_skill_equip_battle` — flake, PASS+PASS on isolated re-run (`arena not found` / turn-wait
  timeout = ISS-106/119 arena-start race).
- `e2e_progression_constraints_with_2` — **NOT a regression.** Bot-01 logs
  `CR-11: PROGRESSION CONSTRAINTS PASSED` + clean teardown; the farm FAIL is **Bot-02 (the
  loser)** forfeiting immediately after `match.found` → `game_forfeit: Game is not in progress`.
  This is the ISS-119 race — a **5th affected scenario** the Ref doc doesn't list yet.
  **TODO:** add `e2e_progression_constraints_with_2` to ISS-119's affected list
  (`issues/Ref_20260722_match_start_race_local_env.md`).

Net: **on this dev machine, the only non-regression reds are the ISS-119 match-start-race family
(privacy_check, match_resolution_forfeit/standard, progression_post_win/constraints, skill_equip,
exotic_weapon, friendly_fire — all intermittent) + ISS-103.** CI (the merge gate) does not
observe the race and stays green. Do NOT "fix" these here.

## 3. Fixes COMPLETED this session (committed on feature branches, NOT pushed)

| RC | Repo / branch | Commit | Change |
|---|---|---|---|
| RC2 | upsilonauth `phase4-auth-cutover-authside` | `37e9296` | `internalAPI.listUsers` returns local `adminUsersPage{items,has_more,next_cursor}` (cursor page via limit+1; `microTime` ported from old hub `admin.go`). Shared `authv1.UsersResponse{users}` left for batch. Public+internal unified (grep confirmed nothing consumes internal `{users}`). Tests: `TestPublicAdminListUsersPaginates`, updated `TestPublicAdminListAndCountUsers`/`TestInternalListUsers`. `go test ./...` green. |
| RC1a | upsilonhub `phase4-player-stats` | `cd9a5e5` | `getProfile` branches on `errors.Is(err, playerstats.ErrNotFound)` → 404 `"You are not enrolled in battle."` (was `must(err)` → 500). `reroll`/`upgrade` left crash-early (owning a character implies a stats row). Test: `TestProfileOfUnenrolledAccountAnswers404`. Full suite green. |
| RC1b | upsiloncli `phase4-infra-cli` | `f076c89` | `e2e_customer_login.js` calls `battle_enroll` after login, before `profile_get` (it manually registers — no `bootstrapBot`, which is what auto-enrolls elsewhere). |

Also filed **ISS-122** (`issues/ISS-122_20260723_battleui_profile_requires_enrollment_guard.md`
+ README index row): battleui SPA reads `/profile` post-login without enroll → will 404 under the
new contract. Deferred to battleui's (still-pending) phase-4 auth adaptation; intentionally OUT of
this atomic cutover's branch set (auth/hub/cli only).

**Decision locked (Bastien, 2026-07-23):** `/api/v1/profile` is battle-scoped — a
registered-not-enrolled account gets a clean **404**, NOT a tolerant empty 200. Fix spanned
hub (404) + cli (enroll) + the ISS-122 SPA follow-up.

## 4. NEXT — finish RC3, then verify + land (in order)

### 4a. RC3 (auth-only) — public admin WRITE endpoints must key on `account_name`, not uuid `:id`
The public admin write routes in `upsilonauth/internal/gateway/router.go` `mountAdmin` are
`POST /users/:id/anonymize` and `POST /users/:id/soft-delete`, so `admin.pathID(c)` parses an
account_name as a uuid → 400 "Invalid user id." The established client contract (upsiloncli
`internal/endpoint/admin.go` **and** battleui `src/Pages/Admin/UserManagement.vue`, both already
correct — DO NOT change them) is:
- Anonymize: `POST /api/v1/admin/users/{account_name}/anonymize`
- Soft-delete: `DELETE /api/v1/admin/users/{account_name}`  (DELETE method, account_name path)

Fix (auth `phase4-auth-cutover-authside`):
1. `mountAdmin`: change the two public write routes to
   `g.POST("/users/:account_name/anonymize", <public>)` and
   `g.DELETE("/users/:account_name", <public>)`. Leave `GET /users` + `GET /users/count-admins`.
   (No gin conflict — different methods vs the static `count-admins`.)
2. New public handlers: resolve `account_name` → user via
   `identity.GetByAccountNameWithTrashed(ctx, name)` (trashed-inclusive so re-anonymize/re-delete
   of an already-soft-deleted account behaves; verify vs the edge scenarios), then
   `identity.AnonymizeAccount(ctx, id)` / `identity.SoftDelete(ctx, id)`. On `ErrNotFound` →
   **404 with the EXACT Laravel-parity message** `No query results for model [App\Models\User] {account_name}`
   (asserted verbatim by `upsiloncli/tests/scenarios/edge_admin_anonymize_nonexistent.js` and
   `edge_admin_delete_nonexistent.js` — read both). Keep success messages ("Account anonymized." etc.).
3. Keep the INTERNAL S2S routes (`mountInternal`: `.../:id/anonymize`, `.../:id/soft-delete`)
   uuid-`:id`-keyed via the existing `anonymizeUser`/`softDeleteUser` handlers → **split**
   public(account_name) vs internal(id); factor the by-id core. Grep the monorepo to confirm no
   internal consumer depends otherwise (same diligence as the listing grep).
4. Tests in `internal/gateway/admin_test.go`: public anonymize + soft-delete (DELETE) by
   account_name (success + 404-nonexistent, exact message). `go build && go vet && go test ./...` green.
   Commit on `phase4-auth-cutover-authside` (no push, no docker).

### 4b. Verify
`docker compose -f docker-compose.ci.yaml down -v && up -d --build --wait` (rebuilds auth+hub+
tester), then re-run `sh ./tests/run_all_scenarios.sh` from `/app/upsiloncli` in the `tester`
container. Expect `admin_user_management` + both admin edge scenarios GREEN; the only remaining
reds should be the ISS-119 race family + ISS-103 (all intermittent; re-run to confirm none is a
new regression).

### 4c. Land atomically (04 §4 step 2) — ONLY after 4b green
The umbrella working tree still holds these UNCOMMITTED, to land in ONE `main` commit:
- infra: `docker-compose.ci.yaml`, `scripts/{build,start,stop}_services.sh`
- submodule pointer bumps: `upsilonauth`→(RC2+RC3 head), `upsilonhub`→`cd9a5e5`, `upsiloncli`→`f076c89`
- docs/issues: `issues/ISS-122_*.md`, `issues/README.md`, this `05_*` handoff (+ the ISS-119
  affected-list edit from §2 if done)
Committing the auth-wired compose to `main` while a submodule pointer lags = broken `main` CI, so
all of the above go together.

### 4d. Then (ask Bastien — 04 §4 step 3)
Merge the 3 submodule branches to their `main`s + push. Gates before any prod cutover still stand:
ISS-118 (per-game GDPR export), ISS-122 (battleui phase-4 adaptation).

## 5. State snapshot (2026-07-23, end of part 2)

- Submodule branch HEADs: auth `phase4-auth-cutover-authside`@`37e9296`,
  hub `phase4-player-stats`@`cd9a5e5`, cli `phase4-infra-cli`@`f076c89`.
- Umbrella `main`: docs/issues from part 1 committed (`dee61f7`); infra + pointer bumps + ISS-122
  + this doc all UNCOMMITTED (working tree `M docker-compose.ci.yaml`, `M scripts/*`,
  `M upsilonauth/upsiloncli/upsilonhub`, `M issues/README.md`, `?? issues/ISS-122_*`, `?? 05_*`).
- The CI stack may still be running from the last verify (`docker compose ... ps`). RC3 is NOT in
  the running auth image — rebuild after fixing.

## 6. Gotchas (unchanged from 04 §6, reconfirmed)
- Monthly spend limit killed an agent again this session (mid-RC3). Watch for it; the fixes' code
  is small — RC3 is ~1 handler split + routes + tests.
- Run the E2E from `/app/upsiloncli` with **`sh`** (busybox), not bash.
- The 6-image stack rebuild picks up submodule source changes (docker build uses the working tree);
  you MUST rebuild auth/hub/tester after their fixes or you'll test stale images.

## 7. Session 2026-07-24 — RC3 finished, suite green, atomic land staged

### RC3 (auth) — DONE
`upsilonauth phase4-auth-cutover-authside @ df97531`. `mountAdmin` public write routes re-keyed to
account_name: `POST /api/v1/admin/users/:account_name/anonymize` + `DELETE /api/v1/admin/users/:account_name`.
New handlers `anonymizeUserByAccountName`/`softDeleteUserByAccountName` + helper `pathAccountUser`
(resolves via `GetByAccountNameWithTrashed`, trashed-inclusive; unknown → 404 with the verbatim
Laravel-parity message `No query results for model [App\Models\User] {account_name}`). Internal S2S
`:id` routes untouched (split public-by-name vs internal-by-id). Tests: `TestPublicAdminAnonymizeAndSoftDelete`
updated to the account_name/DELETE contract; new `TestPublicAdminWriteOnNonexistentAccountAnswers404`.
`go build/vet/test ./...` green; code-health 0 errors.

### RC3b (cli) — a second latent scenario bug behind RC3 — DONE
`upsiloncli phase4-infra-cli @ 5b34ab7`. With RC3 making the anonymize call succeed,
`e2e_admin_user_management` then threw `TypeError: Cannot read property 'message' of undefined` at
line 36: it read `result.message` off `admin.call`, but `admin.call` returns only the envelope's
**data** payload, never the envelope message. The **old in-hub** anonymize returned the mutated user
object as data (`newUserJSON(...)`), so the bad deref silently logged `undefined` and passed; the
extracted **upsilonauth** anonymize returns `data:null` (battleui fires-and-forgets it — confirmed
`UserManagement.vue` reads neither message nor data), so the deref threw once the call stopped 400ing.
Fix: drop the deref (admin.call already throws on a non-2xx envelope) and, per the scenario's stated
intent, actually verify anonymization — re-read the registry, assert `full_address === "ANONYMIZED"`
+ soft-deleted (account_name is preserved by anonymize; the row still lists under default with_trashed).

### Verify — DONE (§4b)
Clean rebuild (`down -v && up -d --build --wait`, all 6 images), full `run_all_scenarios.sh` from
`/app/upsiloncli`: **34 passed / 3 failed**. The 3 = `e2e_battle_starts_privacy_check` (ISS-103),
`e2e_match_resolution_forfeit` + `e2e_match_resolution_standard_with_2` (ISS-119 race). Two other reds
seen in an intermediate run (`e2e_credit_economy` "never reached enemy in 80 rounds";
`e2e_friendly_fire_skill_test` `expected_participants:1`) both PASSED on isolated re-run — same
ISS-119/106 async race family, intermittent on this dev machine, unobserved on CI (the merge gate).

### Atomic land (§4c) — STAGED, awaiting Bastien
Umbrella working tree holds the full bundle, all submodule trees clean, pointers at the new heads
(auth `df97531`, cli `5b34ab7`, hub `cd9a5e5`): infra (docker-compose.ci.yaml + scripts/*), 3 pointer
bumps, issues/README + ISS-122 + the ISS-119 Ref affected-list edit + this handoff. To land in ONE
`main` commit, then (§4d) ask re merging the 3 submodule branches to their mains + push. Gates before
any prod cutover unchanged: ISS-118 (per-game GDPR export), ISS-122 (battleui phase-4 adaptation).
