---
id: req_security_authorization
human_name: Authorization Requirement
type: REQUIREMENT
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[req_security]]
dependents: []
---

# Authorization Requirement

## INTENT
All other UI pages and backend API calls require a valid JWT

## THE RULE / LOGIC
every other ui page (dashboard, waiting room, board page) and all backend api calls require a valid jwt

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[req_security_authorization]]`
