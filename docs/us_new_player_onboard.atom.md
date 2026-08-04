---
id: us_new_player_onboard
human_name: New Player Onboarding Story
type: USER_STORY
layer: BUSINESS
version: 1.0
status: REVIEW
priority: 5
tags: [registration, onboarding, player]
parents:
  - [[uc_player_registration]]
dependents: []
---
# New Player Onboarding Story

## INTENT
Capture the goal and value proposition of a brand-new user creating their first account.

## THE RULE / LOGIC
**As a** new visitor,  
**I want** to create an account using only a username and password  
**so that** I can quickly access the game without friction from excessive personal data collection.

- Acceptance Criterion 1: The registration form must ask for `Account Name`, `Password`, `Full Address`, and `Birth Date`.
- Acceptance Criterion 2: No email field is present or required.
- Acceptance Criterion 3: After success, I am logged in and land on the Game Selection page, where I pick a game to enroll in; reaching the Dashboard requires first enrolling in a game from there — it is no longer a same-flow, no-additional-steps landing.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[us_new_player_onboard]]`
- **Test Names:** `TestUSNewPlayerFormFields`, `TestUSNewPlayerRedirectDashboard`

## EXPECTATION (For Testing)
Registration form rendered -> Fields visible: account_name, password only -> Submit succeeds -> JWT set -> Redirect to Game Selection page.
