# v3 Platform — documentation index

Everything describing the **post-migration v3.0 platform** (the four-game world, service
decomposition, shared vocabularies, observability) lives here. The completed battleui→Go
migration lives in [`../battleui_migration/`](../battleui_migration/); current-state shape is
[`../architecture_anchor.md`](../architecture_anchor.md).

| Doc | What it is | Status |
|---|---|---|
| [`v3_platform_architecture.md`](v3_platform_architecture.md) | The full v3.0 architecture proposal — four games, composition rule, domain map, vocabularies, delivery plan (V3-0…V3-6), decision ledger. | Design (Bastien-approved 2026-07-04); no code yet |
| [`06_v3_platform_constraints.md`](06_v3_platform_constraints.md) | The original user-direction constraints the architecture derives from. | Design constraints |
| [`04_observability.md`](04_observability.md) | OpenTelemetry integration design. Hub is instrumented from it; platform-wide rollout is pending. | Partially delivered (hub only) |
| [`service_extraction/00_identity_economy_extraction.md`](service_extraction/00_identity_economy_extraction.md) | Identity (→V3-1a) & Economy (post-v3.0) extraction plan along the migration seams. | **In progress 2026-07-22** (both pulled into the current extraction) |
| [`service_extraction/02_session_20260722_handoff.md`](service_extraction/02_session_20260722_handoff.md) | **Continuation handoff** for the 2026-07-22 extraction session: decisions, what landed, Phase-3 WIP branch state, exact next steps for Phases 3-5. | Active handoff |
| [`how_to_add_a_service.md`](how_to_add_a_service.md) | **The new-service playbook**: ATD governance, git/submodule wiring, service shell, per-service databases, S2S security, Docker/CI/E2E, OTel — every step as actually exercised by the upsilonauth/upsiloneconomy extractions. | Living reference |
| [`service_map.md`](service_map.md) | **Service→project attribution + bridge map.** The anti-getting-lost index; per-service contract/vision ownership and OTel status. | Living reference |

> Two docs above (`04_`, `06_`) previously lived under `battleui_migration/`; forwarding
> stubs remain at their old paths. The numeric prefixes are kept only to preserve identity.
