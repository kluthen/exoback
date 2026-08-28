# Issue: Front-end Playwright suite + component-isolation visual regression

**ID:** `20260425_frontend_playwright_test_seams`
**Ref:** `ISS-082`
**Date:** 2026-04-25
**Severity:** Medium
**Status:** Open
**Component:** `battleui/`, `docker-compose.yaml`, `CI.md`
**Affects:** Anyone wanting to verify a `BattleArena.vue` / `Components/Arena/Three*.vue` change without manual click-through.

---

## Summary

The `battleui` front-end was rewritten around `@tresjs/core` (Vue + three.js wrapper) but has **no** front-end test scaffolding: no Playwright/Cypress/Vitest deps in `battleui/package.json`, no `tests/Browser/` directory, no `tests/playwright/` directory, no debug seam exposing scene/camera/renderer to the global scope. The CLAUDE.md rule "use the feature in a browser before reporting the task as complete" is currently a stub for any UI work, and the `m battleui` left uncommitted in the working tree (proxy-layer changes from ISS-079/080 plumbing) sits unreviewable for the same reason.

This issue lands a Playwright suite inside the devcontainer with a **two-layer test pyramid**:

- **Layer 1 — real-arena smoke**: load `/battlearena?match_id=…`, assert page-level invariants via a `window.__upsilonDebug` hook, no pixel diffs.
- **Layer 2 — component-isolation visual regression**: dev-only Inertia routes that mount each Three component in isolation with frozen animations; Playwright snapshots compare to committed PNG baselines.

Full-arena visual regression is **out of scope and intentionally so**: arena generation is non-deterministic (Hill terrain, randomized stats/initiative) and animations run continuously. Pixel-diff against a real arena would chase flakes forever. Component isolation gives ~80% of the value at ~30% of the maintenance cost.

---

## Technical Description

### Background

- `battleui/resources/js/Components/Arena/ThreeGrid.vue` uses `<TresCanvas>` from `@tresjs/core` (lines 4–5) and renders cells, obstacles, highlights, and pawns via `TresBoxGeometry`, `TresMeshStandardMaterial`, `TresConeGeometry`, etc.
- The page route is `/battlearena?match_id=<uuid>` (registered in `battleui/routes/web.php`, served by `BattleArena.vue` via Inertia).
- Front-end is served by Vite at `:5173` (dev) or compiled into `public/build/` and served by Apache/Laravel at `:8000` / `:80` (prod via `Dockerfile.prod`).
- Tests will run inside the existing `app` service of `docker-compose.yaml`. Three.js renders under SwiftShader (software rasterizer), which is **deterministic across machines** — the right property for committed PNG baselines.

### The Strategy

#### Layer 1 — Smoke (real arena, no pixels)

```
test('battle arena boots cleanly', async ({ page }) => {
  // Set up a match via API (reuse the upsiloncli bootstrap or fetch direct).
  const matchId = await bootMatchAndJoin(page);
  await page.goto(`/battlearena?match_id=${matchId}`);
  await page.waitForFunction(() => !!window.__upsilonDebug?.scene);
  const sceneSize = await page.evaluate(() => window.__upsilonDebug.scene.children.length);
  expect(sceneSize).toBeGreaterThan(0);
  // No console errors during the load.
  // <canvas> mounted with non-zero dimensions.
});
```

Catches "the page is broken" without snapshots.

#### Layer 2 — Component visual regression (isolated, frozen)

Dev-only Inertia routes:

```
if (! app()->isProduction()) {
    Route::prefix('__test/component')->group(function () {
        Route::get('/', fn () => Inertia::render('TestComponentIndex'));
        Route::get('/{name}', fn (string $name) =>
            Inertia::render('TestComponent', ['name' => $name])
        );
    });
}
```

`Pages/TestComponent.vue` switches on `name`, mounts the matching Three component with **fixed props**, **single light rig**, **single camera angle**, inside `<TresCanvas paused>` (one tick then noop).

Playwright iterates the index, navigates, screenshots, diffs:

```
const names = await fetchTestComponentIndex(page); // small fetch helper
for (const name of names) {
  test(`component: ${name}`, async ({ page }) => {
    await page.goto(`/__test/component/${name}`);
    await page.waitForFunction(() => window.__upsilonDebug?.frozen === true);
    await expect(page.locator('canvas')).toHaveScreenshot(`${name}.png`);
  });
}
```

Initial baseline matrix (~5–10 entries): `cell-default`, `cell-obstacle`, `pawn-team-blue`, `pawn-team-red`, `pawn-dead`, `highlight-attack-range`, `highlight-move-range`. Each PR adds a Three component → adds a route + snapshot in the same commit (CI.md note will spell this out).

### Files to Create / Modify

#### Devcontainer + tooling
- `battleui/package.json` — devDeps: `@playwright/test`, `@types/node`. Scripts: `test:e2e`, `test:e2e:update`, `test:e2e:ui`.
- `battleui/playwright.config.ts` *(new)* — Chromium-only project, `webServer` block boots `php artisan serve --host=0.0.0.0 --port=8000`, `expect.toHaveScreenshot.maxDiffPixelRatio: 0.001`, `outputDir: tests/playwright/.output`, `snapshotDir: tests/playwright/__snapshots__`.
- `battleui/tests/playwright/.gitignore` *(new)* — ignore `.output/`, `playwright-report/`, `test-results/`. **Commit** `__snapshots__/`.
- `docker-compose.yaml` — extend `app` service Dockerfile (or first-`up` step) with `npx playwright install --with-deps chromium`. **No new service.** Image growth ~300 MB.

#### Front-end test seams
- `battleui/resources/js/Pages/BattleArena.vue` — under `if (import.meta.env.DEV || import.meta.env.MODE === 'testing')` set:
  ```ts
  window.__upsilonDebug = { scene, camera, renderer, version: 1, freezeAnimations: () => {…} }
  ```
  Reuses the existing `<TresCanvas>` refs — no duplicate rigging.
- `battleui/resources/js/Components/Arena/ThreeGrid.vue` — accept `paused?: boolean`. When true, render loop ticks once and stops. Used by the Layer 2 fixture.

#### Test-only routes
- `battleui/routes/web.php` — guarded route group above.
- `battleui/resources/js/Pages/TestComponent.vue` *(new)* — switch on `name` prop; mount the matching component inside `<TresCanvas paused>` with fixed props.
- `battleui/resources/js/Pages/TestComponentIndex.vue` *(new)* — bare list of registered names; Playwright reads it to discover the matrix.
- `battleui/tests/Feature/TestRoutesGatedTest.php` *(new)* — single Pest/PHPUnit assertion: `APP_ENV=production` ⇒ `/__test/component` returns 404. Prevents env-guard drift.

#### Test files
- `battleui/tests/playwright/smoke.spec.ts` *(new — Layer 1)*
- `battleui/tests/playwright/components.spec.ts` *(new — Layer 2)*
- `battleui/tests/playwright/__snapshots__/` *(new dir, ~5–10 PNGs initially)*

#### Documentation
- `CI.md` — new "Front-End Tests" section: `battleui/tests/playwright/`, the three-command lifecycle, the convention "every new `Components/Arena/Three*.vue` PR adds a `__test/component/` route and a snapshot in the same commit".
- `battleui/docs/mech_frontend_test_seams.atom.md` *(new IMPLEMENTATION atom)* — documents the `__upsilonDebug` contract and the `__test/component` route family. Keeps the seam ATD-traceable.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood of UI regression slipping through today | High — zero front-end coverage |
| Impact if a Three component breaks silently | Medium — caught at user QA at best, in prod at worst |
| Detectability of a black-screen-but-DOM-fine bug post-PR | High once Layer 2 lands; Low today |
| Maintenance cost of Layer 2 baselines | Low — isolated components, focused PR diffs (one PNG per visual change) |
| Devcontainer image growth | ~300 MB (Chromium only) — non-issue relative to the existing stack |

---

## What This Plan Does **Not** Cover

- **Composition bugs** — multi-cell shadow casting, camera framing on the real arena, depth ordering with mixed pawn states. Layer 1's scene-graph asserts catch most; pixel-level catches require a deterministic seed (separate future issue).
- **Animation timing bugs** — a tween ending one frame too late. Frozen animations sidestep but don't validate. Manual QA / on-demand video recording remains the answer.
- **State-interaction bugs** — "this rendering is wrong only when an entity is dying mid-attack-on-an-obstacle." Hand-rolled component routes don't combinatorially cover. Backfill targeted snapshots if a class of bugs starts slipping through.
- **Cross-browser** (Firefox/WebKit). Single config flag away if a non-Chromium user complains. ~700 MB image weight not worth speculative inclusion.
- **CI workflow wiring**. File a follow-up issue to wire `npm run test:e2e` alongside `e2e-battles.yml` / `edge-case-tests.yml`. Not in this PR.

---

## Escape Hatches (Documented, Not Built)

### Host-GPU execution via SSH (if SwiftShader divergence ever bites)

Single-evening setup, deferred until needed:

1. Host enables OpenSSH server (built-in Mac/Linux; one install on Windows).
2. Generate dedicated keypair inside devcontainer; install pubkey to host with `command="…"` forced-command wrapper that whitelists `npx playwright test …`, plus `from="172.17.0.0/12"` to scope.
3. Container resolves host via `host.docker.internal` (works on Docker Desktop; native Linux needs `--add-host=host.docker.internal:host-gateway` in `runArgs`).
4. Snapshot round-trip is free — both sides bind-mount the repo, so PNG output lands where the container can read it.

Trust boundary not worth standing up speculatively.

### Histoire (Vue Storybook) migration path

If the test-component matrix grows past ~30 entries and hand-maintained `__test/component/` routes become painful, drop in Histoire as the fixture host. Same Playwright snapshots, different rigging. Treat as a future migration, not initial scope.

---

## Verification

1. `cd /workspace/battleui && npm install` — pulls Playwright + Chromium devDeps.
2. `npx playwright install --with-deps chromium` — once.
3. **Smoke layer**: `npm run test:e2e -- smoke` — must pass against `docker compose up -d`. Asserts `__upsilonDebug.scene.children.length > 0`, no console errors, canvas mounted.
4. **Component layer**: `npm run test:e2e -- components`. First run with `--update-snapshots` to lay baselines; `git diff` should show only `__snapshots__/*.png` adds. Subsequent runs byte-exact.
5. **Gate test**: `APP_ENV=production php artisan serve` in another terminal, then `curl -i http://localhost:8000/__test/component/` ⇒ 404. Also covered by `TestRoutesGatedTest.php`.
6. **Existing suites must still pass**: Go (`upsilonapi`, `upsiloncli`, `upsilonbattle`, `upsilonmapdata`) + PHPUnit. The 3 pre-existing PHPUnit failures from the prior session (data-pollution + 500/404 mismatch) remain as-is — not regressed, not fixed in this PR.
7. **Claude-as-tool sanity check**: from inside the devcontainer, run `npx playwright test --reporter=line components.spec.ts`, then `Read tests/playwright/__snapshots__/cell-default.png` to confirm screenshots are interpretable. This closes the "I can verify my UI changes" loop CLAUDE.md requires.

---

## References

- [ISS-079](ISS-079_20260424_cell_access_y_major_standard.md) — cell-access helper landed; layer-flip still pending. Independent of this issue.
- [ISS-080](ISS-080_20260425_error_key_atd_and_envelope.md) — `error_key` taxonomy ATD. Independent.
- [ISS-081](ISS-081_20260425_cross_stack_error_handling.md) — cross-stack error harmonization. Independent.
- `battleui/resources/js/Pages/BattleArena.vue` — primary surface that needs the debug seam.
- `battleui/resources/js/Components/Arena/ThreeGrid.vue` (lines 4–5) — `@tresjs/core` import; the `paused` prop will live here.
- `battleui/routes/web.php` — where the `__test/component` route group lands.
- `docker-compose.yaml` — `app` service to extend with the Playwright install step.
- `CLAUDE.md` — the "use the feature in a browser before reporting done" rule this issue exists to honour.
- Prior session plan file: `/home/vscode/.claude/plans/so-browserless-chrome-or-playwright-cozy-valley.md` (verbatim source for this issue).

---

## Update (2026-06-16 — WP-B4, Wave-1 remediation)

Reopened. The audit found this was marked Resolved while CI reported "❌ No HTML
Report found" and the suite was effectively under-exercised.

**Root cause of the report gap (fixed):** `battleui/playwright.config.ts` had **no
`reporter` configured** (defaulted to `list`), so the `battleui/playwright-report/`
directory that `.github/workflows/ci.yml` checks for (line 236) and uploads as an
artifact was never created. Fixed by adding the `html` reporter (default output
folder `playwright-report/`), plus `timeout: 60s` and CI `retries: 1` /
`forbidOnly` to bound runaway specs. CI already runs the **full** suite
(`ci.yml:213`, `continue-on-error`); artifacts now capture. Added `.gitignore`
entries for `playwright-report/`, `tests/playwright/.output/`, `battle_screenshot.png`.

**Live suite status (2026-06-16, all 6 specs, against the running stack):**

| Spec | Result |
|---|---|
| `battle_debug` | ✅ pass |
| `user_flows` | ✅ 9 passed / 1 skipped |
| `battle_arena` | ❌ fail — "render the arena correctly" |
| `visual_smoke_test` | ❌ fail — gather logs and DOM |
| `battle_arena_sandbox` | ⏱ hang/timeout |
| `components` | ⏱ hang/timeout |

**Remaining work (NOT done — real frontend regressions, not test scaffolding):**
the 2 failing + 2 hanging specs are genuine `BattleArena.vue` / arena-rendering
regressions, originally tied to the 846-LOC god-component flagged in ISS-084
("Refactor BattleArena into components and restore visual effects" — now
Resolved/deleted) and the audit frontend report. They were deliberately NOT
papered over (no assertions weakened). Re-verify against the now-decomposed
`BattleArena.vue` as a dedicated frontend-stabilization pass; this issue stays
Open until the suite is green.
