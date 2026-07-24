# Issue: GDPR export loses per-game data coverage under the game-agnostic account model

**ID:** `20260722_gdpr_export_per_game_gap`
**Ref:** `ISS-118`
**Date:** 2026-07-22
**Severity:** Medium
**Status:** Open
**Component:** `upsilonauth/internal/gateway` (export), `upsilonhub/internal/gateway` (game data)
**Affects:** GDPR `GET /api/v1/auth/export` consumers; every future game service

---

## Summary

Under the 2026-07-22 remodel, upsilonauth's `GET /auth/export` returns account data + registered services only — it no longer aggregates characters/game data (the hub's Laravel-era export bundled the roster). GDPR data-portability, however, covers **all** personal data, including game-local state (characters, match history, inventory, ledgers). Until each game exposes its own export and something composes them, the platform's export answer is incomplete.

---

## Technical Description

### Background

Pre-extraction, one process owned all tables, so one export query covered everything. Post-extraction, personal data is deliberately spread: auth (account), economy (wallet + ledgers), each game (characters, stats, history).

### The Problem Scenario

1. Player invokes their GDPR export right via `GET /api/v1/auth/export`.
2. Auth returns account + registrations (+ tokens metadata).
3. Characters, match history, inventory and credit ledgers exist in hub/economy databases but are absent from the response.
4. The platform has technically under-delivered on data portability.

### Where This Pattern Exists Today

- `upsilonauth/internal/gateway` export handler (returns `characters: []` placeholder as of the Phase-1 scaffold).
- Hub still owns the full data until Phase 4/5 cutover — so today the *hub's* export path is authoritative; the gap opens at cutover.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High — every export request after cutover is incomplete |
| Impact if triggered | Medium — compliance/user-trust, no availability impact |
| Detectability | Low — the response succeeds, just with less data |
| Current mitigant | Cutover not done yet; deletion path is unaffected (auth's durable purge fan-out zeroes wallets and anonymizes the account) |

---

## Recommended Fix

**Short term:** Before the Phase-4 cutover, document the reduced export scope in the export response itself (a `scope` field listing what is included) so it is honest, and keep this issue open as the cutover gate's known exception.

**Medium term:** Each service exposes an internal export fragment (`GET /internal/v1/gdpr/export/{user_id}` on economy and on each game); auth's export composes the fragments of the services the account is registered to (it already knows the registration list).

**Long term:** Make the export fragment part of the "how to add a service" checklist — a service that stores personal data MUST ship its fragment endpoint before going live (add to `architecture/how_to_add_a_service.md` §7/§0 gates).

---

## Extra Data

Born from the 2026-07-22 game-agnostic accounts remodel (auth = account+registrations only; games own their data). Deletion/anonymization is already handled durably (auth River fan-out → economy purge); export is the only right that regressed.

---

## References

- `upsilonauth/docs/contract_auth_service.atom.md` (GDPR clause)
- `architecture/how_to_add_a_service.md`
- `issues/Ref_20260722_upsilonapi_dependabot_vulns.md` (same session's security pass)
