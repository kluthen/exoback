# Issue: Logout during the sliding-renewal window leaves the freshly-minted replacement token live

**ID:** `20260826_auth_renewal_logout_revocation_hole`
**Ref:** `ISS-137`
**Date:** 2026-08-26
**Severity:** Medium
**Status:** Open
**Component:** `upsilonauth/internal/gateway/auth.go` (RevokeToken) / `upsilonauth/internal/identity/identity.go` (sliding renewal)
**Affects:** `upsiloncli/internal/script/bridge.go` (session token sync), any client that can race a request against its own logout

---

## Summary

A latent revocation hole was found while investigating ISS-130 (it is **not** the cause of ISS-130
and was never triggered by it — ISS-130's scenario never got far enough to exercise renewal at
all; this is filed purely on its own merit). If introspection performs sliding token renewal on
the very request that is subsequently followed by logout, `middleware.AuthToken` hands back the
**old** token to the caller, and `RevokeToken` at logout time deletes only that one row. The
freshly-minted replacement token that renewal issued in the background is never touched and
remains live and usable after the client believes it has logged out.

---

## Technical Description

### Background

Introspection performs sliding renewal: when a token's age falls inside a window, the identity
layer mints a replacement token transparently so a long session doesn't need re-authentication.
Logout is expected to end the session for good by revoking the caller's current token.

### The Problem Scenario

```
CLI / client                 upsilonauth
─────────────                ───────────
request N  (token=T_old, age=12m, inside 10-15m renewal window)
                              introspect(T_old) -> valid
                              renewal fires -> mints T_new, T_old still stored too
  middleware.AuthToken returns T_old to the caller (T_new is not surfaced here)
upsiloncli jsCall syncs "renewed" token into session
  (bridge.go:168) -- if it picks up T_old rather than T_new, session is now
  holding a token that is about to be revoked while T_new lives on unseen

logout(T_old) ──────────────► RevokeToken deletes ONLY T_old's row
                              T_new row is untouched, still valid, still usable
request N+1 (token=T_new) ──► introspect(T_new) -> still valid, 200 OK
                              (expected: 401, session was supposed to be over)
```

`RevokeToken` (`upsilonauth/internal/gateway/auth.go:151-155`) deletes exactly the one token ID it
is handed; it has no notion of a token lineage/family, so a renewal-spawned sibling is invisible
to it.

### Why It Is Latent, Not Active Today

Renewal only fires when token age is between 10 and 15 minutes
(`upsilonauth/internal/identity/identity.go:31-33`). Any scenario or real session shorter than that
window never reaches the renew-then-revoke interleaving, so the hole has not manifested in
observed CI runs to date.

### Note: The Baseline Revocation Chain Is Sound

This is not a report that revocation is broken in general. The normal chain was verified correct
end to end during the ISS-130 investigation: `logout` -> `RevokeToken` -> `DeleteToken`
(`upsilonauth/internal/identity/pg.go:253-255`) -> `FindTokenByID` -> `pgx.ErrNoRows` ->
`ErrUnauthenticated` -> `{active:false}` -> 401, pinned by a passing `TestIntrospectRevokedToken`
(`upsilonauth/internal/gateway/introspect_test.go:83-99`). The hole is specifically the
renew-then-revoke interleaving — revoking a token whose lineage has already forked — not
revocation itself.

### Where This Pattern Exists Today

- `upsilonauth/internal/gateway/auth.go:151-155` — `RevokeToken`, deletes exactly one token ID.
- `upsilonauth/internal/identity/identity.go:31-33` — sliding renewal window (10-15 minutes).
- `upsiloncli/internal/script/bridge.go:168` — `jsCall` syncs a renewed token into the session,
  compounding the exposure client-side if the wrong half of the pair gets propagated.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Low today — requires a request to land inside the narrow 10-15 minute renewal window immediately before logout; no observed occurrence in CI |
| Impact if triggered | Medium — a token the user believes is revoked remains usable until natural expiry |
| Detectability | Low — introspection on the replacement token returns a normal 200; nothing distinguishes it from a legitimately still-valid session |
| Current mitigant | None — `RevokeToken` has no concept of token lineage |

---

## Recommended Fix

**Short term:** Document the interleaving as a known gap so it is not mistaken for the (unrelated,
already-resolved) ISS-130 symptom if it is ever observed.

**Medium term (suggestions, not decisions):**
1. Revoke the whole token lineage/family on logout, not just the single token ID the client
   presents.
2. Alternatively, have the renewal path make the superseded token's replacement discoverable to
   `RevokeToken` (e.g. a successor pointer on the old row) so a revoke-by-old-ID call can cascade.

**Long term:** Consider whether sliding renewal should mutate the existing token row in place
(same ID, refreshed expiry) rather than minting a new row, which would remove the lineage-tracking
problem entirely — flagged here as a direction, not a decision, since it may have other tradeoffs
this issue does not evaluate.

---

## References

- `upsilonauth/internal/gateway/auth.go:151-155` — `RevokeToken`.
- `upsilonauth/internal/identity/identity.go:31-33` — renewal window.
- `upsilonauth/internal/identity/pg.go:253-255` — `DeleteToken`.
- `upsilonauth/internal/gateway/introspect_test.go:83-99` — `TestIntrospectRevokedToken`, pins the
  sound baseline chain this issue does not dispute.
- `upsiloncli/internal/script/bridge.go:168` — `jsCall` session token sync.
- Related: [ISS-130](ISS-130_20260819_revoked_token_not_rejected.md) — found while investigating
  that report; unrelated cause, this hole was never triggered by it.
