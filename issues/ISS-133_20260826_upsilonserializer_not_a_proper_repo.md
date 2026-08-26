# Issue: upsilonserializer is a single-consumer in-tree module masquerading as a shared library — evaluate folding it into upsilonapi

**ID:** `20260826_upsilonserializer_not_a_proper_repo`
**Ref:** `ISS-133`
**Date:** 2026-08-26
**Severity:** Low
**Status:** Open
**Component:** `upsilonserializer/`
**Affects:** `upsilonapi/api/output.go`, `upsilonapi/bridge/bridge_resurrect.go`, `upsilonapi/bridge/resurrection_test.go`, `go.work`

---

## Summary

`upsilonserializer` is listed in `CLAUDE.md`/`UPSILON.md` as one of the shared Go libraries alongside `upsilontypes`, `upsilonmapdata`, `upsilonmapmaker`, `upsilontools` — but unlike those, it is **not a Git submodule**: it's an in-tree Go module (`./upsilonserializer` in `go.work`, package `github.com/ecumeurs/upsilonserializer`) that isn't a proper independent repo. It also has exactly one consumer today, `upsilonapi`, and is used for a single symbol: `upsilonserializer.CurrentSerializerVersion`, to stamp and validate the `SerializerVersion` field on board-state blobs during resurrection. Worth checking out whether the indirection is pulling its weight or whether it should just be merged into `upsilonapi` as an internal package.

---

## Technical Description

### Background

`go.work` composes several umbrella modules, most of which are genuine Git submodules shared (or intended to be shared) across multiple services. `upsilonserializer` sits in that same list and reads like a shared library, but has no independent repo of its own and is consumed nowhere except `upsilonapi`.

### The Problem Scenario

```
go.work
  ├── ./upsilonhub          (submodule, multi-consumer)
  ├── ./upsilonapi          (submodule) ──imports──> upsilonserializer.CurrentSerializerVersion
  ├── ./upsilontypes        (submodule, shared)
  ├── ./upsilonserializer   (NOT a submodule — plain in-tree module, single consumer: upsilonapi)
  └── ...

Consumers of "github.com/ecumeurs/upsilonserializer" (repo-wide grep):
  upsilonapi/api/output.go:14,426            — stamps SerializerVersion on outgoing board state
  upsilonapi/bridge/bridge_resurrect.go:18,68 — validates SerializerVersion on resurrection
  upsilonapi/bridge/resurrection_test.go      — tests around the above
  (no other service — hub, auth, economy, battle, cli — imports it)
```

Carrying a separate module boundary (separate `go.mod`, separate `go.work` entry, separate versioning surface) for a single constant/type consumed by one service adds indirection without the benefit a real shared library provides (independent versioning, reuse across services, independent release cadence).

### Where This Pattern Exists Today

- `go.work:13` — `./upsilonserializer` module entry
- `upsilonserializer/go.mod` — `module github.com/ecumeurs/upsilonserializer`
- `upsilonapi/api/output.go:14,426`
- `upsilonapi/bridge/bridge_resurrect.go:18,68`
- `upsilonapi/bridge/resurrection_test.go:13,194,195,248,279`

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | N/A — this is a structural/maintenance question, not a failure mode |
| Impact if triggered | Low — mislabeling in docs and unnecessary module boundary, not a functional bug |
| Detectability | Low — only surfaces when someone tries to treat `upsilonserializer` as a real submodule (e.g. in `scripts/push_all.sh`, submodule bump workflows) and it behaves differently |
| Current mitigant | None; it currently works fine as-is, this is a "should we simplify" question, not an active defect |

---

## Recommended Fix

**Short term:** Document in `UPSILON.md`/`CLAUDE.md` that `upsilonserializer` is an in-tree module, not a submodule, so it isn't mistakenly assumed to follow submodule bump/push workflows (`scripts/push_all.sh`).

**Medium term:** Investigate whether `upsilonserializer` should be collapsed into `upsilonapi` as an internal package (e.g. `upsilonapi/internal/serializer`), since it has exactly one consumer and a small surface (`CurrentSerializerVersion` and whatever else lives in the package). Confirm there's no near-term plan to give it a second consumer (e.g. `upsilonbattle` or another engine-adjacent service) before folding it in — if there is, keep it separate and just fix the submodule mislabeling instead.

**Long term:** If a genuine second consumer emerges, promote it to a real Git submodule at that point rather than pre-emptively decoupling code that has never been reused.

---

## Extra Data

Investigation performed 2026-08-26: repo-wide `grep -rl "upsilonserializer"` across all `.go` files and `go.mod`/`go.work` confirms `upsilonapi` is the sole consumer, limited to the `CurrentSerializerVersion` symbol.

---

## References

- `go.work`
- `upsilonserializer/go.mod`
- `upsilonapi/api/output.go`
- `upsilonapi/bridge/bridge_resurrect.go`
- `upsilonapi/bridge/resurrection_test.go`
- `CLAUDE.md` (§1 Project Map — lists `upsilonserializer` among shared Go libraries)
