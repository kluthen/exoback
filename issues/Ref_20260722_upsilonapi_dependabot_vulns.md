# Issue: upsilonapi default branch carries 15 Dependabot vulnerabilities (7 critical)

**ID:** `20260722_upsilonapi_dependabot_vulns`
**Ref:** `ISS-117`
**Date:** 2026-07-22
**Severity:** High
**Status:** Open
**Component:** `upsilonapi/go.mod`
**Affects:** `upsilonapi` (engine bridge, :8081), transitively any deployment exposing it

---

## Summary

On pushing to `ecumeurs/upsilonapi` (2026-07-22, go.work-sync dependency commit), GitHub reported **15 open Dependabot alerts on the default branch: 7 critical, 2 high, 6 moderate** (https://github.com/ecumeurs/upsilonapi/security/dependabot). The alerts predate the push; the sync commit only *raised* transitive versions (gin stack, sonic, otel), so the vulnerable ranges are in older pins or in dependencies the sync did not touch. upsilonapi is not internet-exposed in prod (behind Caddy/EC2 security groups) but processes untrusted JSON from authenticated clients, so parser/HTTP CVEs are the concerning class.

---

## Technical Description

### Background

upsilonapi is a thin Gin JSON bridge to the battle engine. Its dependency surface is small (gin, logrus, uuid, testify + transitive), so 15 alerts most likely concentrate in the gin/net-http/sonic transitive graph.

### The Problem Scenario

1. A CVE lands in a pinned transitive dependency (e.g. a JSON parser used by gin bindings).
2. No process watches the Dependabot tab; the alert ages silently.
3. An authenticated (or S2S) caller sends a crafted payload that reaches the vulnerable code path.

### Where This Pattern Exists Today

- `upsilonapi/go.mod` / `go.sum` — the flagged graph.
- Alert list (needs GitHub UI/API review): https://github.com/ecumeurs/upsilonapi/security/dependabot
- Same exposure class exists for every other repo in the org; upsilonapi is simply the one GitHub flagged on this push.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Medium — service is not public, but parses untrusted payloads from clients |
| Impact if triggered | High — engine bridge compromise = full game-state authority |
| Detectability | Low — nothing surfaces Dependabot alerts into the team's workflow |
| Current mitigant | Caddy front door + private networking; 2026-07-22 go.work sync already bumped much of the gin/otel graph |

---

## Recommended Fix

**Short term:** Triage the 15 alerts in the GitHub security tab; `go get -u` the flagged modules in upsilonapi, `go work sync`, run the full suite + CI. Most Go transitive CVEs clear with patch bumps.

**Medium term:** Add `govulncheck ./...` to the umbrella CI build stage (it checks the *called* code paths, cutting alert noise to real exposure).

**Long term:** Enable Dependabot security updates (auto-PRs) org-wide, and make `scripts/repo_status.sh --fetch` or CI surface open-alert counts so they can't age silently.

---

## Extra Data

Discovered during the v3 service extraction session (Phase 0 push). The three new repos (upsilonplatform/upsilonauth/upsiloneconomy) start from the freshly unified graph and should be clean; verify once Dependabot scans them.

---

## References

- https://github.com/ecumeurs/upsilonapi/security/dependabot
- `upsilonapi/go.mod`, `upsilonapi/go.sum`
- `.github/workflows/ci.yml` (build stage — govulncheck insertion point)
