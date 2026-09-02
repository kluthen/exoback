# Issue: The admin skill-template endpoint accepts arbitrary unregistered property keys with 201 Created — registry validation is deferred to battle time

**ID:** ISS-156_20260902_admin_skill_template_no_registry_validation
**Ref:** ISS-156
**Date:** 2026-09-02
**Severity:** Medium
**Status:** Open
**Component:** `upsilonhub/internal/gateway/admin_content.go`
**Affects:**
- `upsilonhub/internal/gateway/admin_content.go:235-237` — create path, `targeting`/`costs`/`effect`
- `upsilonhub/internal/gateway/admin_content.go:281-288` — update path, same three blocks
- `upsilonhub/internal/gateway/admin_content.go:409-411` — `checkPresentArray`, applies `present|array` only
- `upsilonapi/bridge/bridge_utils.go:140-180` — `buildSkillPropertyMap` / `buildSkillEffect`, where validation actually happens
- `upsilonhub/internal/gateway/admin_content_test.go:116-125` — `TestSkillTemplateCRUDLifecycle`, currently asserts the broken behaviour is fine
- `upsilonhub/internal/gateway/matchmaking_pve_test.go:262-276` — raw SQL fixtures with legacy lowercase keys
- `upsilonhub/internal/gateway/skill_roll_test.go:20-40` — `fakeGeneratedSkill`, same legacy shape

## Summary

`POST`/`PUT` on `/api/v1/admin/skill-templates` validate only that the `targeting`, `costs` and
`effect` blocks are **present and are arrays/objects**. Their key *content* is never checked against
the Skill-scoped property registry. `admin_content.go:3` states the design plainly: the blocks "are
captured raw so the stored" payload passes through untouched.

Consequence: an admin can create a skill template whose keys resolve to nothing, and the API answers
**`201 Created`**. The failure only surfaces much later, when a real battle tries to use the skill and
`upsilonapi`'s bridge rejects the keys with `ErrUnknownPropertyKey` / `ErrPropertyKeyWrongScope`.

This is a **content-authoring gap**, not test noise: authoring-time acceptance of data that is
guaranteed to fail at use time violates crash-early (CODING_RULE §3) and pushes an avoidable failure
to the worst possible moment — mid-battle, for a player.

## Evidence

`TestSkillTemplateCRUDLifecycle` (`admin_content_test.go:116-125`) posts:

    targeting: {"range":3}, costs: {"mp":4}, effect: {"damage":7}

None of `range`, `mp`, `damage` are registry keys (the real ones being `Range`, `MPLeech`,
`DamageScale`) — every one is the lowercase legacy Laravel shape. The request succeeds. The test
currently encodes the defect as expected behaviour.

Two further hub fixtures carry the same legacy shape and would be rejected by the real bridge; both
use a **fake** `upsilonapi` client, so the validator is never exercised:

- `matchmaking_pve_test.go:262-276` — raw SQL `INSERT`s using `range`/`sp`/`mp`/`damage`
- `skill_roll_test.go:20-40` — `fakeGeneratedSkill`, explicitly a port of the old PHP test data

## Scope

- Validate the three blocks against the Skill-scoped registry at authoring time, rejecting unknown and
  wrong-scope keys with a 4xx that names the offending key.
- Decide where the shared validator lives: `buildSkillPropertyMap`/`buildSkillEffect` currently sit in
  `upsilonapi/bridge`, and the hub must not grow a second divergent copy of the rules.
- Zone values need the same treatment — `ZoneProperty.Set` **panics** on an unrecognised pattern
  (valid: `Single`, `Neighbours`, `Circle:N`, `Square:N`, `Line:N`), so an unvalidated `Zone` string
  stored today is a latent panic at battle time.
- Update the three fixtures above to registry-valid keys as part of the fix; `TestSkillTemplateCRUDLifecycle`
  must be inverted to assert rejection.

## Notes

Found during the property-key unification round's skill-definition sweep. Related: **ISS-140** (legacy
seed schema, data side now fixed).
