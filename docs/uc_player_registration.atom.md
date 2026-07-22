---
id: uc_player_registration
human_name: Player Registration Use Case
type: USER_STORY
layer: ARCHITECTURE
version: 1.0
status: STABLE
priority: 5
tags: []
parents:
  - [[upsilonbattleui:req_player_experience]]
dependents:
  - [[us_new_player_onboard]]
  - [[upsilonbattleui:ui_registration]]
---
# Player Registration Use Case

## INTENT
To allow a new user to enter the ecosystem by creating a persistent account and establishing their initial character roster.

## THE RULE / LOGIC
1. **Data Entry**: Guest provides mandatory registration data (`Account Name`, `Password`, `Full Address`, `Birth Date`).
2. **Account Creation**: System validates data against security policies (`rule_password_policy`).
3. **Character Generation**: System generates an initial roster of 3 characters with randomly distributed attributes.
4. **Review & Reroll**: User can review the roster and optionally reroll the entire set up to 3 times (`ui_registration_reroll_limit`).
5. **Persistence**: Upon confirmation, the system persists the account and characters to the database.
6. **Authentication**: System generates a JWT for the new session.
7. **Transition**: User is redirected to the **Dashboard** (`ui_dashboard`).

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_player_registration]]`

## EXPECTATION (For Testing)
- Submission of valid form -> Characters generated -> Success leads to Dashboard redirection with valid JWT.
- Reroll button disabled after 3 attempts.
- No personal data (like Email) is collected per `us_new_player_onboard`.
