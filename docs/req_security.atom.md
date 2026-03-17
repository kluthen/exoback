---
id: req_security
human_name: Sanctum Token Security Requirement
type: MODULE
version: 1.1
status: STABLE
priority: CORE
tags: [auth, sanctum]
parents: []
dependents: [req_security_authorization, req_security_public_access, req_security_token_ttl]
---

# Sanctum Token Security Requirement

## INTENT
To aggregate the constituent rules of Sanctum Token Security.

## THE RULE / LOGIC
Ensures that all non-public requests to the application are authenticated using Laravel Sanctum Personal Access Tokens.
- A token is issued upon successful login or registration.
- The token must be sent in the `Authorization` header as a Bearer token.
- Format: `Authorization: Bearer <token>`

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[req_security]]`
