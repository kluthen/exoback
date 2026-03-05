---
id: uc_match_resolution_win_detection
human_name: Win Detection Logic
type: USECASE
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[uc_match_resolution]]
dependents: []
---

# Win Detection Logic

## INTENT
Detect when a player wins the match.

## THE RULE / LOGIC
The Go backend checks the victory condition: are all characters on the opposing team at 0 HP?

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_match_resolution_win_detection]]`
