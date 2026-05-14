# Best Practices for Agentic Development

Principles that transfer across stacks. Read once; reread when something breaks and you can't explain why.

---

## Principle 1 — Enforcement beats documentation, every time

Documentation describes intent. Hooks, permissions, and CI enforce it.

If you find yourself writing *"the agent should..."* in CLAUDE.md, ask: **can I make this true instead of expected?**

| Aspiration in docs | Enforced version |
| --- | --- |
| "Tests must pass before commit" | Commit-gate hook running tests |
| "No secrets in code" | Secret-scan hook |
| "Don't touch migrations" | `permissions.deny` on `migrations/` |
| "Use Conventional Commits" | `commit-msg` hook validating the message regex |
| "App Router only" | Hook blocking new files in `pages/` |

What stays in docs: things that need *judgement* (naming, architecture choices, when to break the rule). Things that have a clean yes/no answer go in hooks.

---

## Principle 2 — Plan-gate before edit-gate

The cheapest place to catch a wrong direction is **before code is written**. Every minute in plan-mode saves 10 minutes of code-and-revert.

- **Force plan-mode for anything > 1 file** (configurable per repo).
- **Reject plans that don't cite CLAUDE.md** — sign the agent skipped reading it.
- **Reject plans that don't list a test strategy** — testing should be designed, not retrofitted.
- **Approve plans with caveats** when the direction is right but a detail is wrong. Don't bounce a whole plan over one line item.

---

## Principle 3 — CLAUDE.md is a contract, not a wishlist

Bad CLAUDE.md:

> Try to write clean code. Follow conventions. Use existing patterns.

Good CLAUDE.md:

> Source lives in `src/`. Tests in `tests/` mirror the structure.
> Public exports are explicit — no `*` re-exports.
> Logging goes through `src/lib/logger.ts`; never call `console.log` directly.
> The check command is `pnpm check`; if it doesn't exist in `package.json`, add it before doing the work.

A good CLAUDE.md is **specific, command-level, falsifiable**. A reader could disagree with it. Vague platitudes are noise.

**Keep it under 200 lines.** If it's longer, you're trying to encode taste — that goes in hook enforcement or human review.

---

## Principle 4 — Small, frequent PRs > big batched ones

A PR that takes >30 minutes to review is a PR that doesn't get reviewed. Agents are *especially* prone to giant PRs because they can keep adding "while I'm here" changes for free.

- **400-line diff cap** as a soft rule. Bigger means split.
- **One ticket = one PR.** If the agent says "while implementing PROJ-123 I noticed PROJ-X is also wrong" — file PROJ-X as a new ticket and ignore it for this PR.
- **Draft → ready transition is meaningful.** Use draft for "I'm still working"; ready for "human, please look".

---

## Principle 5 — Two reviewers, two contexts

Self-review by the agent that wrote the code is theater. The point of `/review` and `/security-review` is that **they don't share the writer's context** — they read the diff like a stranger would.

- Run *both* on every PR over a few-line threshold.
- Each is allowed to disagree with the other. Don't merge their outputs.
- The writing agent addresses findings or explains why not — *in the PR body*, so the human sees the reasoning later.

---

## Principle 6 — Hooks should be boring

A hook that's elegant or clever is a hook that breaks at 11pm on a Friday.

- **Short scripts, single responsibility.** One hook = one check.
- **Local-only.** No network calls. No "phone home to lint server".
- **Idempotent.** Running twice should be a no-op.
- **Fast.** PreToolUse on Edit/Write must be < 1s. PreToolUse on Bash `git commit` must be < 60s.
- **Quiet on success, loud on failure.** stdout for nothing; stderr for the message that explains the block.

---

## Principle 7 — Trust the toolchain, gate the toolchain

For each language, there's a *canonical* set of tools that's been battle-tested:

- **Node:** Vitest, ESLint flat config, Prettier, tsc.
- **.NET:** xUnit, `dotnet format`, Roslyn analyzers, `Directory.Build.props`.
- **Next.js:** Vitest + Playwright, `next lint`, Prettier, tsc.

Use them. Don't roll your own linter, don't build a custom test framework. The agent has seen these tools in training; it knows the conventions.

**Gate the canonical chain** in your commit-gate hook and in CI. Both must run the *exact same commands*. If local says green and CI fails, your gates aren't aligned — fix immediately.

---

## Principle 8 — Failure should be self-explaining

When a hook blocks, when a test fails, when CI breaks — the agent will try to fix it. The fix quality depends entirely on how clear the error message is.

- **Bad:** `Error: exit code 1`.
- **Good:** `[guard-commit] dotnet test failed: 3 tests in OrderServiceTests failed (see TestResults/). Most likely cause: the new IRepository signature isn't matched in the test setup. Fix the test mocks or revert OrderService.cs.`

Yes, you write that yourself in the hook script. It pays for itself in fewer wasted agent turns.

---

## Principle 9 — Memory is for what's stable; CLAUDE.md is for what's project-specific; hooks are for what's enforced

Three layers of persistence — don't confuse them:

| Layer | Lives in | Scope | Updates |
| --- | --- | --- | --- |
| Memory | `~/.claude/.../memory/*.md` | Across all repos | Long-lived facts about user / team / preferences |
| CLAUDE.md | Repo root | This repo | Repo-specific conventions and commands |
| Hooks | `.claude/settings.json` | This repo | Hard-enforced rules |

Things to NOT put in memory: code patterns (read the code), recent changes (read git log), debugging fixes (read the commit). Memory is for **non-derivable** facts.

---

## Principle 10 — Never let the agent merge or deploy

The two actions that matter most are reserved for humans. Always.

- Agent: creates PR, polls CI, fixes failures, summarizes for human.
- Human: clicks Merge. Clicks Deploy.

Hooks enforce this via `permissions.deny`:

```json
["Bash(gh pr merge:*)", "Bash(vercel deploy --prod:*)", "Bash(az webapp deploy:*)"]
```

The agent can suggest. It cannot ship. That single boundary keeps the whole loop safe enough to run with high autonomy upstream.

---

## Principle 11 — Update CLAUDE.md every time you correct the agent

If you tell the agent the same thing twice — "we don't use `var` for primitives", "tests go in `tests/`, not next to source" — that's not the agent's fault. CLAUDE.md is incomplete.

Add a line. Five minutes once means you never explain it again. This is how the workflow gets smarter over time.

---

## Principle 12 — When in doubt, smaller scope

The single most common failure mode of agentic dev: **the agent takes on more than the ticket said.**

It refactors "while it's there". It "improves" surrounding code. It "fixes" tests it doesn't understand.

- In plan-mode review, ask: *"Is this the minimum to satisfy the AC?"* If no, cut.
- In code review, ask: *"Does this hunk relate to the ticket?"* If no, cut.
- In PR review, ask: *"Could this be a smaller PR?"* Usually yes.

Smaller wins compound. Big bangs implode.

---

## Putting principles into practice — quarterly review checklist

Run this every 3 months on each repo using the workflow:

- [ ] Are there places I'm repeating myself in PR review? → new hook.
- [ ] Are there hooks that haven't blocked anything in 3 months? → delete them.
- [ ] Is CLAUDE.md longer than 200 lines? → split or trim.
- [ ] Is the commit-gate hook slower than 60s? → move slow checks to CI.
- [ ] How many memory entries are now stale or contradict current state? → prune.
- [ ] Did the agent loop forever on any ticket this quarter? → tune the auto-retry cap.

Workflows that aren't pruned regularly grow barnacles. A clean, fast loop with 5 hooks beats a sluggish loop with 30.
