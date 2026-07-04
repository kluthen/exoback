---
trigger: always_on
---

# Upsilon Hub: Operational Standards & Guards

These rules are non-negotiable for all implementation work in Upsilon Hub.

## 1. Communication Layer Protocol
- **API Envelope**: Never modify the communication layer without ensuring compliance with `[[api_standard_envelope]]`.
- **Documentation Sync**: Any alteration to the communication API (path, payload, behavior) MANDATORILY requires a corresponding update to `communication.md`, Postman collections, and relevant ATD atoms.
- **Warning**: Altering serialization or the bridge API contract must trigger an explicit warning for the user to approve.

## 2. Error Handling Philosophy
- **Crash Early**: Defaulting hides critical errors. Avoid silent failures or catch-all default values in the core logic.
- **Fail Fast**: We are in development mode; clear panics or rejections are better than undefined behavior.

## 3. Testing Tool Usage
- **Selective Testing**: Do **NOT** use `trigger_all_ci_tests.sh`. It is too slow and destructive to the current session.
- **Precision Testing**: Always use `scripts/trigger_one_ci_test.sh` for targeted scenario validation.
- **Unit Tests**: `run_all_unit_tests.sh` is lightweight and should be run frequently during refactoring.
- **Isolation**: Testing is meant to test production code. Avoid adding "test-only" logic to production files unless absolutely necessary for observability.
- **Reproduce Error as Test First**: when a new error is encountered, ensure a test is created at the nearest concerned module that will reproduce the error. Only then, attempt to solve the error.

## 4. Artifact Management
- **Binary Output**: All compiled binaries must be placed in the `bin/` directory of their respective service.
- **Gitignore Enforcement**: The `bin/` folder is strictly ignored in `.gitignore`. Never commit compiled binaries to the repository.
- **Build Convention**: Build commands should explicitly specify the output path: `go build -o bin/service-name ./cmd/service-name`.
- **Documentation**: Include build instructions in each service's `README.md` with the explicit binary output path.

## 5. Code Health & Governance (Zero Error Standard)
All code must adhere to the "Zero Error" health standard enforced by `scripts/code_health_check.py`.

NOTE: the script isn't intelligent enough to differentiate our code from third party framework (like laravel). In which case: add a @lint-ignore-all

### 5.1 File Bloating
- **Warning**: Files exceeding **400 effective LOC** (excluding imports and blank lines).
- **Error**: Files exceeding **600 effective LOC** (excluding imports and blank lines).
- **Bypass**: Use `@lint-ignore-file-bloating` only for exceptional cases.

### 5.2 Logic Complexity
- **Nesting Depth**: Maximum allowed nesting depth is **4 levels**.
- **Error**: Functions exceeding this limit must be refactored.
- **Bypass**: Use `@lint-ignore-complexity` only when refactoring is architecturally impossible, or in too complex and critical circonstances.

### 5.3 Documentation Density
- **Intent Documentation**: All functions require preceding comments describing their purpose, inputs, and outputs.
- **Exposed Functions**: Missing documentation on public/exported functions is an **Error**.
- **Internal Functions**: Missing documentation on private/internal functions is a **Warning**.
- **Bypass**: Use `@lint-ignore-documentation`, only for exceptionnal cases, or heavily inherited template/class/interface (like one parent template/class/interface inherited dozen times). 

### 5.4 ATD Traceability
- **Density**: Every source file must contain at least **1** ATD link (`@spec-link` or `@test-link`).
- **Link Limits**: Maximum **10** ATD links per file (Warning at >5).
- **Test Files**: Must use `@test-link` exclusively; `@spec-link` is prohibited in test environments.
- **Integrity**: Phantom links (references to non-existent Atom IDs) are strictly prohibited.
- **Bypass**: Use `@lint-ignore-atd`, mostly for things out of scope of our project.