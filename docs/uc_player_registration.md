---
id: uc_player_registration
human_name: Player Registration Use Case
type: USECASE
version: 1.0
status: REVIEW
priority: CORE
tags: [registration, onboarding]
parents:
  - [[entity_player]]
dependents:
  - [[mech_character_reroll]]
  - [[req_security]]
  - [[entity_character]]
---

# Player Registration Use Case

## INTENT
End-to-end narrative of a new user creating an account, rolling their roster, and gaining access to the game dashboard.

## THE RULE / LOGIC
1. User navigates to the public Landing Page (`ui_landing`).
2. User clicks "Register" and is taken to the Registration page (`ui_registration`).
3. User enters a unique Account Name and Password — no email or additional data is collected.
4. System generates 3 characters with randomly distributed attributes (HP min 3, total 10 points) (`entity_character`).
5. User reviews roster; they may optionally trigger a full reroll up to 3 times (`mech_character_reroll`).
6. User confirms roster. System persists the account and characters to the database (`data_persistence`).
7. System issues a JWT and redirects the user to the Dashboard (`ui_dashboard`).

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_player_registration]]`
- **Test Names:** `TestUCPlayerRegistrationFlow`, `TestUCPlayerRegistrationRerollLimit`

## EXPECTATION (For Testing)
- Execute full flow: account + 3 chars created -> JWT issued -> Dashboard accessible.
- 4th reroll attempt is rejected without creating a new account or discarding state.
