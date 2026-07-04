---
trigger: always_on
---

# IDE Agent Ruleset: Atomic Traceable Documentation (ATD)

**Core Mandate:** Documentation and code co-evolve as a verifiable graph. Maintain bidirectional traceability from requirements to code and tests.

### 1. The Atom Blueprint
Every atom (`.atom.md`) must follow this structure:

```markdown
---
id: unique_slug
human_name: "Human Readable Name"
type: MECHANIC
layer: IMPLEMENTATION
version: 1.0
status: DRAFT
priority: 3
tags: [tag1, tag2]
parents:
  - [[parent_atom_id]]
dependents:
  - [[child_atom_id]]
---

# Human Readable Name

## INTENT
[One sentence: Why does this exist? No "and" or "also".]

## THE RULE / LOGIC
[Core specification: pseudo-code, formulas, or strict bullets.]

## TECHNICAL INTERFACE
- **Code Tag:** `@spec-link [[unique_slug]]`
- **Test Names:** `TestMyLogic1`

## EXPECTATION
[Verifiable acceptance criteria.]
```

### 2. Document Types & Granularity
Use this table for `type`, `layer`, and granularity. **Bloat Factor** (0.1-1.0) defines strictness (1.0 = laser-focused).

| Type | Family | Layer | Bloat | Granularity |
|---|---|---|---|---|
| `VISION` | Strategic | N/A | 0.1 | Broad vision (no code/test links) |
| `CONTRACT` | Strategic | N/A | 0.3 | External agreement (no code/test links) |
| `REQUIREMENT` | Requirements | BUSINESS | 0.3 | High-level external contract |
| `RULE` | Logic | BUSINESS/ARCH | 0.8 | Single business constraint |
| `USER_STORY` | Requirements | BUSINESS | 0.1 | User workflow |
| `API` | Interface | ARCHITECTURE | 0.1 | Single contract with payloads |
| `UI` | Interface | ARCHITECTURE | 0.8 | One screen or flow |
| `ENTITY` | Architectural | ARCHITECTURE | 0.8 | Single data model |
| `MECHANIC` | Logic | IMPLEMENTATION | 0.8 | One algorithm or validation |
| `MODULE` | Architectural | ARCHITECTURE | 0.3 | Service or broad grouping |
| `DOMAIN` | Logic | BUSINESS | 0.8 | Narrative context |

> [!IMPORTANT]
> `VISION` and `CONTRACT` types are strategic. They cannot be linked to code/tests or business layer atoms.

### 3. The "Minimum Atomic Scale" Rule
* Each atom describes exactly ONE rule.
* If `## INTENT` needs "and" or "also", split it.
* Check tolerances via `atd_config(bloating_factor=...)`.

### 4. Tool Guardrails
* **No manual rewrites:** Use `atd_update` for all `.atom.md` modifications.
* **Deterministic first:** Use `atd_query`, `atd_trace`, `atd_crawl`, `atd_weave` for structure.
* **Delegate analysis:** Use LLM-backed tools:
  - `atd_discover`: Map code to atoms (default), confirm match (`atom`), or propose new (`new: true`).
  - `atd_recon`: Validate if a file implements an atom.
  - `atd_check`: Coverage report (`@spec-link` / `@test-link`). Use `semantic: true` for LLM compliance.
  - `atd_trace(summary=true)`: Mandatory for vertical context before changes.

### 5. Workflow Loop
1. **Plan:** Find atoms via `atd_query`/`atd_search`. Create `DRAFT` atoms via `atd_update`.
2. **Specify:** Link upward via `parents`. Run `atd_weave` to sync dependents.
3. **Implement:** Run `atd_trace(summary=true)`. Annotate code with `@spec-link` and tests with `@test-link`.
4. **Verify:** Run `atd_check` for coverage. Ensure ancestry exists (Business ← Architecture ← Implementation).
5. **Evolve:** Run `atd_crawl` before modifying `STABLE` atoms to assess impact.

### 6. Traceability Tagging
* **No Global Headers:** Place tags directly above the relevant class, function, or block — never in package/file-level comments.
* **Tests Tag Tests:** Test files carry `@test-link` only (atop each test function); `@spec-link` is reserved for implementation code.
* **Discovery:** Use `atd_discover` if unsure where to place tags in undocumented code.

### 7. Hierarchy & Volatility
* **BUSINESS (`REQUIREMENT`, `RULE`):** Low volatility. Need explicit permission to alter `STABLE` atoms (include `atd_crawl` impact analysis).
* **ARCHITECTURE (`API`, `UI`, `ENTITY`):** Moderate volatility. Run `atd_crawl` before changes.
* **IMPLEMENTATION (`MECHANIC`):** High volatility. Update freely during refactoring.

### 8. Health & Roots (The Trace Rule)
* **Top-Down is OK:** BUSINESS/ARCHITECTURE atoms can have 0% coverage (on the to-do list).
* **Roots are Mandatory:** IMPLEMENTATION atoms must have ancestry. If `has_customer_origin: false`, stop and ask for the upstream requirement.

### 9. Workspace & Multi-Project
In multi-project environments (see `.atd.workspace`):
1. **Init:** Run `atd_workspace_list` to see projects.
2. **Context:** Use `atd_workspace_use(project=...)` before ATD operations.
3. **Cross-Ref:** Use `project:atom_id` prefix (e.g., `[[api:auth_login]]`).

### 10. Best Practices
**DO:**
- Start features with ATD atoms.
- Use `atd_search` to avoid duplicates.
- Run `atd_weave` after any atom creation/modification.
- Update status: `DRAFT` → `REVIEW` → `STABLE`.

**DON'T:**
- Break `@spec-link` chains during refactoring.
- Write code without an upstream atom (missing `has_customer_origin` is a blocker).
- Create broad atoms (no "and"/"also" in intent).

### Quick Reference
```bash
# Discovery
atd_query(field="type", search="RULE")
atd_discover(file="src/foo.go", new=true)

# Structure
atd_update(file="docs/x.atom.md", set=["status=STABLE"])
atd_weave()

# Health
atd_check(semantic=true)
atd_trace(atom="id", summary=true)
atd_crawl() # Impact analysis
```