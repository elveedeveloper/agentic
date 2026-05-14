# AGENT-1 — Add `farewell(name)` function

> This file is the **durable contract** for the story. The agent reads it first,
> before any plan-mode exploration. If anything in this file is ambiguous or
> outdated, ask in chat before proceeding — don't guess.

## Summary

Add a `farewell(name)` function to the `hello` app, mirroring `greet(name)` but
with a defined empty-string edge case.

## Description

The `hello` app currently exposes a single function, `greet(name)`, which
returns `` `Hello, ${name}!` ``. To validate the full agentic loop end-to-end,
we want a second function — `farewell(name)` — that follows the same shape but
exists in its own module with its own tests.

This is deliberately a trivial scope. The point is to exercise every stage of
the loop (spec → plan → branch → test-first → code → guard hooks → review → PR
gate) on a story so small that any friction visible in the loop is signal about
the loop itself, not about the task.

## Acceptance criteria

- [ ] New file `src/farewell.ts` exports a value named `farewell`.
- [ ] `farewell` has the TypeScript signature `(name: string) => string`.
- [ ] `farewell("World")` returns the literal string `"Goodbye, World!"`.
- [ ] `farewell("Salman")` returns the literal string `"Goodbye, Salman!"`.
- [ ] `farewell("")` returns the literal string `"Goodbye!"` (no trailing comma, no space — empty-name edge case).
- [ ] New file `tests/farewell.test.ts` contains at least one test for the happy path and one test for the empty-string edge case. Both must pass.
- [ ] `npm run check` is green at the end (typecheck + lint + format + tests).

## Test strategy

- Mirror the structure of `tests/greet.test.ts`: one `describe('farewell', ...)` block, one `it(...)` per acceptance bullet.
- Use Vitest's `describe` / `it` / `expect` — no other test helpers.
- No mocking is required (the function is pure).
- Optional: add a third test covering a name with whitespace (e.g., `"  "`) — _not_ an AC, but a nice-to-have if trivial.

## Out of scope

The agent must **not** do any of the following in this story:

- Modify `src/greet.ts` or `tests/greet.test.ts` in any way (including reformatting).
- Introduce a shared helper like `formatMessage` or refactor `greet` to deduplicate. Two trivial pure functions are fine.
- Create an `index.ts` barrel re-exporting both functions.
- Add JSDoc comments — the type signature is self-documenting at this size.
- Touch `.claude/`, `package.json`, `tsconfig.json`, `eslint.config.js`, `.prettierrc.json`, or any tooling/CI config.
- Bump dependencies.
- Add a CLI entry point or `bin` field.

If during the work you notice something genuinely worth doing that's outside the AC, **file it as a separate ticket** in this `specs/` folder rather than expanding this one.

## Branch + commit conventions

- Branch name: `AGENT-1/farewell`.
- Commit message format (Conventional Commits): `feat: add farewell function (AGENT-1)`.
- One commit for the implementation is fine; split into `test:` + `feat:` if you wrote the test first and want to show that in history.

## Estimated complexity

Trivial. Implementation is ~3 lines; tests are ~10 lines. The whole story should take well under 5 minutes of agent time excluding gates.
