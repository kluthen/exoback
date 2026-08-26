# Issue: ATD papertrail cleanup — pre-existing defects deferred from the ISS-102/103/130/131 round

**ID:** `20260826_atd_defects_deferred_from_102_103_130_131_round`
**Ref:** `ISS-139`
**Date:** 2026-08-26
**Severity:** Low
**Status:** Open
**Component:** ATD papertrail (`docs/*.atom.md` across umbrella + submodules)
**Affects:** `upsilonhub/internal/gateway/enroll.go`, `upsilonhub/internal/gateway/authenticator.go`, `upsilonhub/internal/transport/authclient/client.go`, the `ZoneProperty` AoE-targeting atom chain, `req_security`, `requirement_customer_user_id_privacy` (and its new dependent `requirement_foe_loadout_privacy`), `upsilonapi/docs/api_websocket*`, and the `atd check` tool itself

---

## Summary

A documentalist D2 blast-radius pass over the ISS-102/103/130/131 round surfaced a set of ATD
defects that all **predate** that round and were deliberately deferred to keep the round bounded.
Two siblings from the same sweep were already fixed in-round and are recorded here purely for
cross-reference — they are **not** part of this issue's scope:
- the broken atom id `mechanic_mec_skill_payload_resolution` (extra `mec_` infix) at 11 sites — fixed.
- `edge_auth_session_timeout.js:2` test-link retargeted from `req_security_token_ttl` to
  `uc_auth_logout` — fixed.

The seven items below are the deferred, still-open defects.

---

## Technical Description

### The Problem List

1. **`contract_auth_service` used as an `@spec-link` target** at `upsilonhub/internal/gateway/enroll.go:45`
   and `authenticator.go:66`. This is a hard-boundary violation: CONTRACT atoms are never
   `@spec-link`/`@test-link` targets (per ATD governance). Needs re-pointing at the appropriate
   REQUIREMENT/MECHANIC atom instead.
2. **`mech_actor_pattern` mis-tag on `ZoneProperty`** — tagged unprefixed, but the prefixed
   `upsilontools:mech_actor_pattern` is a concurrency-actor atom entirely unrelated to AoE
   targeting. Wrong atom, not merely a wrong reference.
3. **`atd lint` failure: `req_security` is missing a mandatory `## EXPECTATION` section.**
4. **`atd lint` failure: `requirement_customer_user_id_privacy` is missing a mandatory
   `## EXPECTATION` section.** This round parented a new atom
   (`requirement_foe_loadout_privacy`) to this one, so the incompleteness now has a live
   dependent riding on an incomplete parent.
5. **`contract_auth_service` content drift** — its `## EXPECTATION` describes a caller-side
   introspection cache bounded to seconds, but `upsilonhub/internal/transport/authclient/client.go`
   has no cache at all: `AuthenticateToken` introspects live on every request
   (lines 56-65). DRAFT atom, low stakes. This independently corroborates the finding recorded in
   the ISS-130 correction — the long-assumed "5s introspection cache" was designed but never
   built.
6. **`api_websocket*` atoms misplaced under `upsilonapi/docs/`** while actually documenting
   hub-owned SSE. Urgency is unchanged or higher than when first noticed: they are `@spec-link`'d
   to no real code at all today.
7. **`atd check` substring-tolerant matching yields false positives** — it reported "OK" on the
   broken `mechanic_mec_...` id (defect list item above, already fixed) for months, masking that
   defect the entire time. This is a verification-tooling gap worth its own remediation in its own
   right, since it undermines confidence in every other `atd check` "OK" result until addressed.

### Explicitly Out of Scope — Context Only, Not an Action Item

`atd index` has never been built in this workspace, so `atd search` / `atd map` / `atd congruence`
/ `atd crawl --gaps` all run degraded, producing documented false negatives and phantom orphans.
The user has stated building the index is theirs to resolve. Do **not** file this as work; it is
recorded here only so the degraded-tooling context is visible alongside item 7 above (which is a
distinct defect in `atd check`'s matching logic, not the missing-index problem).

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Low — these are papertrail/documentation defects, not runtime risks |
| Impact if triggered | Low individually; item 7 (false-positive `atd check`) has a wider blast radius since it can mask other defects the same way it masked the `mechanic_mec_...` id for months |
| Detectability | Low for items 1-6 (require a manual blast-radius pass to notice); item 7 is specifically about detectability itself being broken |
| Current mitigant | None; all seven are open |

---

## Recommended Fix

**Short term:** Track all seven items here as a single deferred cleanup backlog so they are not
lost; none are individually urgent enough to block other work, which is why they were deferred
from the ISS-102/103/130/131 round in the first place.

**Medium term (suggestions, not decisions):**
1. Re-point the two `@spec-link [[contract_auth_service]]` sites (item 1) at a REQUIREMENT/MECHANIC
   atom.
2. Correct the `ZoneProperty` mis-tag (item 2) to whatever atom actually governs AoE targeting.
3. Add the missing `## EXPECTATION` sections to `req_security` and
   `requirement_customer_user_id_privacy` (items 3-4) — the latter is now blocking, in spirit, on
   `requirement_foe_loadout_privacy`'s own completeness story.
4. Reconcile `contract_auth_service`'s EXPECTATION text with the actual no-cache implementation
   (item 5) — either build the cache as designed or rewrite the atom to describe live introspection.
5. Relocate `api_websocket*` atoms (item 6) to the hub's docs tree and re-point their `@spec-link`s
   at real SSE code.

**Long term:** Fix `atd check`'s substring-tolerant matching (item 7) so a broken/misspelled atom
id cannot silently pass as "OK" — this is the highest-leverage single fix in this list since it
protects against every other defect class recurring undetected.

---

## References

- ISS-102/103/130/131 round (`3db0e9d`) — the round this sweep was performed during.
- `upsilonhub/internal/gateway/enroll.go:45`, `authenticator.go:66` — item 1.
- `upsilonhub/internal/transport/authclient/client.go:56-65` — item 5.
- `upsilonapi/docs/` — item 6.
- Related: [ISS-130](ISS-130_20260819_revoked_token_not_rejected.md) — corrected-on-record source of
  the "no introspection cache exists" finding corroborated by item 5.
