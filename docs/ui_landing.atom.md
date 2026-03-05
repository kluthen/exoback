---
id: ui_landing
human_name: Landing Page UI
type: UI
version: 1.0
status: REVIEW
priority: CORE
tags: [ui, public, landing]
parents: []
dependents:
  - [[ui_registration]]
  - [[req_security]]
---

# Landing Page UI

## INTENT
To serve as the public-facing promotional entry point for the TRPG, offering paths to register or log in.

## THE RULE / LOGIC
- Content: Promotional material describing the tactical RPG game.
- Actions:
  - Must provide a clear "Log In" entry point leading to authentication.
  - Must provide a clear "Register" entry point leading to the Registration page.
- Security: This page is public and must not require JWT authentication.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[ui_landing]]`
- **Test Names:** `TestLandingPageRendersPublicly`

## EXPECTATION (For Testing)
- Unauthenticated user navigates to root `/` -> Sees promotional content and login/register buttons.
