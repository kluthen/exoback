# Issue: BattleUI API Refactoring and Todo List

**ID:** `20260316_battleui_api_todo_list`
**Ref:** `ISS-019`
**Date:** 2026-03-16
**Severity:** Medium
**Status:** Resolved
**Component:** `battleui/app/Http/Controllers/API`
**Affects:** `battleui` API consumers

---

## Summary

This issue tracks the transition of the BattleUI backend to a more robust and standard API structure, focusing on extracted validation (FormRequests), consistent Model-to-DTO mapping (API Resources), and a review of the Sanctum authentication flow.

---

## Technical Description

### Task 1: FormRequest Migration
Currently, most controllers in `battleui` use inline validation or untyped `Request $request` objects. We need to create and use the following FormRequests:

- **Auth**
    - [ ] `Auth/LoginRequest`: Swap `AuthController::login` inline validation for the existing (or updated) class.
    - [ ] `Auth/RegisterRequest`: Extract registration validation from `AuthController::register`.
    - [ ] `Auth/UpdateAccountRequest`: Extract validation from `AuthController::updateAccount`.
- **Profile**
    - [ ] `Profile/UpdateProfileRequest`: Extract validation from `ProfileController::updateProfile`.
    - [ ] `Profile/UpdateCharacterRequest`: Extract complex validation logic from `ProfileController::updateCharacter`.
- **Matchmaking**
    - [ ] `Matchmaking/JoinMatchRequest`: Add validation for `game_mode` in `MatchMakingController::joinMatch`.
- **Game**
    - [ ] `Game/ActionRequest`: Extract validation from `GameController::action`.

### Task 2: API Resources to implement:
- [ ] `UserResource`: For `User` model (Auth/Profile).
- [ ] `CharacterResource`: For `Character` model (Profile).
- [ ] `GameMatchResource`: For `GameMatch` model (Matchmaking).
- [ ] `MatchParticipantResource`: For `MatchParticipant`.
- [ ] `MatchmakingQueueResource`: For `MatchmakingQueue`.

### Task 3: Authentication Review
- [x] Audit `auth:sanctum` middleware usage across all sensitive routes in `routes/api.php`.
- [x] Review `AuthController` token lifecycle management.
- [ ] Consider refactoring manual authorization checks (e.g., in `ProfileController::rerollCharacter`) into Laravel Policies or custom Middleware.

### Task 4: Profile & Character Ownership Enforcement
- [x] Refactor `ProfileController` to remove the `{id}` parameter from routes.
- [x] Ensure `ProfileController` methods (getProfile, updateProfile, getCharacters, etc.) use the authenticated `$request->user()` instead of a user-provided ID.
- [x] Update `routes/api.php` to reflect these changes.

---

## Recommended Fix

**Short term:** Implement the missing `FormRequest` classes to clean up controllers.
**Medium term:** API Resources to implement.
**Long term:** Migrate to standard Laravel `JsonResource` if the custom DTO structure is not strictly required by external services (like the Upsilon Go Engine).

---

## References

- [api.php](file:///home/bastien/work/upsilon/projbackend/battleui/routes/api.php)
- [AuthController.php](file:///home/bastien/work/upsilon/projbackend/battleui/app/Http/Controllers/API/AuthController.php)
- [ProfileController.php](file:///home/bastien/work/upsilon/projbackend/battleui/app/Http/Controllers/API/ProfileController.php)
- [MatchMakingController.php](file:///home/bastien/work/upsilon/projbackend/battleui/app/Http/Controllers/API/MatchMakingController.php)
