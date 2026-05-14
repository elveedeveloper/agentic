# First-Run Report — AGENT-1 (farewell function)

**Date:** 2026-05-14
**Story:** [`apps/hello/specs/AGENT-1.md`](../apps/hello/specs/AGENT-1.md)
**Branch:** `AGENT-1/farewell` (local; never pushed — see "Carryover blockers")
**Commits on the branch:** `acbebc8` (baseline) · `074b06c` (spec) · `7ed694e` (feat + tests)

## TL;DR

The agentic loop worked end-to-end as designed, up to but not including the
push/PR step (push auth is the open blocker carried over from session start).
Five tests pass, two independent reviewers agreed the change is sound, no
guard hook had to be overridden. The test bed is now a real, runnable app
under [`apps/hello/`](../apps/hello/) suitable for story #2 and beyond.

The friction surfaced was almost entirely about the templates, not about
the workflow — useful signal, listed below.

## What worked

- **Spec-as-file held the line.** Writing `specs/AGENT-1.md` before any code meant the in-story plan, the implementation, the tests, *and* the reviewers all referenced the same contract. Scope did not creep. The "Out of scope" list was honored without prompting.
- **Plan gate at the in-story level caught a real decision.** The whitespace-only test was an explicit fork — your "Approve + add whitespace test" answer locked it in *before* it was code. That's the cheap correction the plan gate exists for.
- **Two reviewers, two perspectives — exactly as principle 5 predicts.** Code reviewer (3 nits, none blocking) and security reviewer (no concerns) pulled in different directions and found different things. Neither rubber-stamped.
- **TDD cycle was clean.** Wrote the test → confirmed RED with the exact "cannot find `farewell.js`" error → wrote impl → confirmed GREEN. Five tests across two files in 1.21s.
- **Conventional Commits worked downstream.** History reads cleanly with `git log --oneline`; the `(AGENT-1)` suffix means Jira (when wired) will auto-link.
- **Guard hooks (where invoked) did their job.** No need to override anything.

## What broke or surprised me — the actual signal

1. **`templates/node/tsconfig.json` has `rootDir: "src"` but the natural include for typecheck is `src/**/* + tests/**/*`.** TypeScript errors with `TS6059` because tests aren't under rootDir. Fixed in `apps/hello/tsconfig.json` by dropping `rootDir` (we don't emit; typecheck is `--noEmit`). **Tuning for templates:** drop `rootDir` from the template's tsconfig, OR add a comment explaining it's for build-mode and that typecheck-only repos should remove it.

2. **The format hook (`PostToolUse` on `Edit|Write|MultiEdit`) didn't fire automatically.** Why: I'm running Claude Code at the repo root (`Agentic/`), but the hook is configured at `apps/hello/.claude/settings.json`. Claude Code only picks up `.claude/` from its own working directory. I had to run `npm run format` manually twice. **Tuning:** either (a) document "open Claude Code inside the app folder, not the monorepo root" in `docs/workflow.md` Stage 3, or (b) add a *secondary* `.claude/settings.json` at the repo root that delegates to the app dir.

3. **`/security-review` skill failed** with `fatal: ambiguous argument 'origin/HEAD...'`. The skill assumes a pushed branch with a tracked upstream; pre-push (which is where the local loop lives) it can't compute the diff. **Tuning:** raise this upstream as a fallback request (diff against `main` when `origin/HEAD` is missing), or document a one-line alias in `docs/workflow.md` Stage 5: when pre-push, spawn a security-review subagent via the Agent tool with the diff against `main`.

4. **Bash working directory didn't persist across invocations** on this Windows setup. Each `Bash` call started in a default cwd; `cd apps/hello && ...` worked *within* the call but the next call was back where it started. Worked around with absolute paths and `git -C`. **Tuning:** add a note in `docs/hooks-cookbook.md` or `CLAUDE.md` boilerplate that hook commands should use `process.cwd()` consciously, not assume a path.

5. **`vitest.config.ts` declares coverage thresholds (80/80/70/80) but `npm run check` never runs coverage.** The thresholds are aspirational, not enforced. **Tuning:** either drop them from the template until they're enforced, or extend `check` to `npm run test:coverage` (slower, but the gate matches reality).

6. **Prettier round-trips on markdown italics** (`*not*` → `_not_`). Minor but worth knowing: a freshly-committed file can become "modified" again on the next `npm run format`. Hardly broken, just a footnote.

7. **Push auth blocked** (carryover from session start). The local loop completed without pushing; the PR + CI babysitter stages couldn't run. **Action item:** resolve the github auth before story #2 if you want the full Tier-1+CI loop, or keep doing local-only runs and stage CI integration for a dedicated session.

## Reviewer findings — disposition

| # | Finding | Severity | Action |
| - | --- | --- | --- |
| 1 | Code review: ternary vs explicit `if` in `farewell.ts` | Nit | **No change** — reviewer flagged as non-blocking and justified by the AC. |
| 2 | Code review: whitespace test pins ugly output `"Goodbye,   !"` | Nit | **No change** — behavior is correct per spec and impl; the test asserts a real property. |
| 3 | Code review: AC checkboxes in spec still `- [ ]` | Nit | **No change** — spec is a frozen contract, not a status doc. The completion signal is the merged PR, not edits to the spec. |
| 4 | Security review: none | — | n/a |

All three nits could be argued either way. They're recorded here as the audit trail; nothing was silently dropped.

## Factory-flavored additions — verdict after one run

Of the four I proposed at the start:

| Addition | Verdict | Why |
| --- | --- | --- |
| **Spec-as-file** | ✅ Keep, expand | Did real work this run. Worth promoting from "apps/hello convention" to "all stacks" by adding a `specs/` section to each template's CLAUDE.md. |
| **Run log / session replay** | ⚠️ Worth trying | Authored alongside this report as `apps/hello/.agent-runs/AGENT-1.md`. Evaluate after a few more stories whether it earns its maintenance cost. |
| **Cost ceiling per session** | ⏸ Defer | Tier-1 local runs don't risk runaway. Re-evaluate when we wire `claude-from-jira.yml` for autonomous runs. |
| **Primer file** | ❌ Skip | Overlaps with CLAUDE.md without adding signal. CLAUDE.md already serves this role for a single-app repo. Reconsider if/when the monorepo grows past 3 apps. |

## Recommended next steps, in order

1. **Resolve the push auth** so future stories can exercise PR + CI stages. (Or accept that local-only validation is the scope for now.)
2. **Apply the 5 template tunings above** (tsconfig rootDir, hook placement docs, /security-review fallback, coverage thresholds, working-dir note). Bundle them into a single PR titled something like `chore(templates): fixes surfaced by AGENT-1 first run`.
3. **Story #2:** pick another trivial story to validate the *tuned* templates. Suggestion: "Add a `shout(message)` function that returns the message in upper-case, with tests" — same shape, but exercises a tiny bit of standard-library use (`.toUpperCase()`) so we test that the loop doesn't choke on anything fancier than template literals.
4. **Story #3:** once #2 is green, attempt the *same* story on the `templates/dotnet/` stack — that validates the multi-stack workflow requirement and surfaces stack-specific friction (PowerShell hooks, `dotnet restore` time, etc.).
5. **Only then** consider adding `claude-review.yml` (Tier-2 #1), once Tier-1 has run cleanly on at least two stacks.

## Time / cost notes

Wall-clock time for the full Stage A → C run: roughly 30 minutes including npm install (~23s) and review-subagent latency. No specific token budget tracked — worth adding for story #2 to baseline what "small story" actually costs.
