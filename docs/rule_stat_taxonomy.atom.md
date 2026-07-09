---
id: rule_stat_taxonomy
status: STABLE
version: 2.0
priority: 5
human_name: Character Stat Taxonomy (Class A vs Class B)
parents:
  - [[rule_progression]]
type: RULE
tags: [stats, progression, items, iss-074]
dependents:
  - [[upsilonbattleui:ui_character_full_stat_panel]]
layer: BUSINESS
---

# Character Stat Taxonomy (Class A vs Class B)

## INTENT
To divide character properties into two classes based on whether players can level them up via Character Points: Class A (CP-upgradable, persisted) vs Class B (item / buff only, never CP-upgradable). This rule is the single source of truth for "can the upgrade UI show this stat?" and "should the dashboard show a CP cost next to this stat?".

## THE RULE / LOGIC
**Class A — Character-leveled (CP-upgradable, persisted on `characters` table):**
- HP, MP, SP (resource counters, 1 CP each per +1)
- Attack, Defense (5 CP each per +1)
- Movement (30 CP per +1)
- JumpHeight (15 CP per +1)
- CritChance (10 CP per +1%)
- CritDamage / CritMultiplier (5 CP per +5%)

Class A stats are surfaced in the upgrade UI with their explicit CP cost and persisted as columns on the `characters` table.

**Class B — Effective-only (granted by items / buffs only, NEVER CP-upgradable):**
- AttackRange (default 1, modified by ranged weapons)
- Shield (default 0, modified by shielding effects)

Class B stats:
- Are NOT surfaced in the upgrade UI.
- Are NOT persisted as columns on `characters`.
- Default values come from the engine's `PropertiesForCharacter()` factory.
- Appear on the dashboard only as an item or buff contribution.
- Attempting to upgrade a Class B stat via `/profile/character/{id}/upgrade` returns 422 (validation rejection).

**Why this split exists:**
- AttackRange in particular changes the tactical reach of a character. Allowing it to be CP-upgraded would warp positioning without an item-trade-off; restricting it to weapons keeps it scoped to deliberate equipment choices.
- Shield as a CP-upgrade would compete directly with HP at the same cost without adding strategic depth; restricting it to buffs / shielding effects keeps it situational.

**Companion atoms:**
- `[[rule_progression]]` defines CP costs for Class A.
- `[[upsilonbattle:mechanic_item_buff_application]]` is how Class B stats are projected onto entities.

## TECHNICAL INTERFACE
- **Code Tag:** `@spec-link [[rule_stat_taxonomy]]`
- **Controller:** `App\Http\Controllers\API\ProfileController::upgradeCharacter` (rejects Class B upgrades).
- **Frontend:** `Components/Character/CharacterStatPanel.vue` (renders Class B without CP cost).
- **Test Names:** `TestUpgrade_ClassBStatsRejected`

## EXPECTATION
- Class A upgrade requests succeed within CP budget; Class B upgrade requests return 422.
- The character upgrade endpoint validation request whitelist includes only Class A keys.
- The dashboard renders all 11 stats (9 Class A + 2 Class B) but only shows CP cost on Class A.
