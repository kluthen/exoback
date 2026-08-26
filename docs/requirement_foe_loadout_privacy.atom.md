---
id: requirement_foe_loadout_privacy
status: DRAFT
version: 1.0
type: REQUIREMENT
layer: BUSINESS
priority: 3
human_name: Foe Loadout Privacy
dependents:
  - [[upsilonhub:module_foe_loadout_masking]]
tags: security,privacy,battle
parents:
  - [[requirement_customer_user_id_privacy]]
---

# New Atom

## INTENT
To ensure that a player's tactical loadout — the skills, items, and active buffs equipped on their characters — is never exposed to an opposing player during a match, preventing an opponent from reading the player's build or strategy through the API/SSE feed before it is actually revealed through play.

## THE RULE / LOGIC
- A foe-owned entity (any entity where the viewing player is not the owner) MUST NOT expose its equipped_skills, equipped_items, or buffs to that viewer, in any board-state payload the viewer receives, regardless of transport.
- A player's own entities retain full visibility of their own equipped_skills, equipped_items, and buffs.
- This privacy rule is orthogonal to internal-identifier masking ([[upsilonapi:arch_api_id_masking_gateway]]): stripping raw database UUIDs does not, by itself, satisfy this rule, and satisfying this rule does not require stripping identifiers — they are two independent masking concerns that happen to apply to the same board-state payload.

## TECHNICAL INTERFACE
Any board-state payload delivered to a specific viewer — whether via the realtime event stream or an HTTP polling endpoint — must omit foe-owned equipped_skills, equipped_items, and buffs for every entity that viewer does not own. This applies uniformly across every delivery channel serving board state; it is not satisfied by fixing only one channel while leaving another unmasked.

## EXPECTATION
- A player viewing an opponent's entity never receives that entity's equipped_skills, equipped_items, or buffs, on every channel that delivers board state to them.
- The same player, viewing one of their own entities, receives that entity's equipped_skills, equipped_items, and buffs unchanged.
- This holds from the first frame the viewer receives for a match onward — there is no window in which foe loadout data is briefly visible before masking catches up.
