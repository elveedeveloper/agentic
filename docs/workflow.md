# The Agentic Dev Workflow — Full Walkthrough

This is the seven-stage loop the templates support, written from the perspective of *what happens when a ticket comes in*.

Each section has:
- **What happens** — concrete actions.
- **Best practices** — how to do it well.
- **Failure modes** — what tends to go wrong, and how to avoid it.
- **Per-stack notes** — where Node / .NET / Next.js differ.

---

## Stage 1 — Story intake (Jira → Claude)

### What happens

1. Atlassian MCP connector is authenticated once per machine (`mcp__claude_ai_Atlassian__authenticate`).
2. You ask Claude something like: *"Pick the top To-Do ticket in PROJ sprint 12 assigned to me."*
3. Claude queries Jira via the MCP, reads the description, acceptance criteria, comments, and linked tickets.
4. Claude transitions the ticket to **In Progress** and posts a Jira comment like *"Picked up by Claude agent at 2026-05-13T14:02Z. Plan to follow."* — so humans see activity in Jira even if they don't look at GitHub.

### Best practices

- **One ticket per session.** Don't let the agent pull multiple tickets in parallel — context bleeds, scope creeps.
- **Read linked tickets and comments**, not just the description. Half of the real acceptance criteria usually lives in a Slack thread someone pasted into a comment.
- **If the AC is vague, push back in Jira.** A good agent leaves a comment asking the question instead of guessing. A bad agent guesses.
- **Don't auto-assign unowned tickets to yourself.** Pick from your already-assigned queue. Auto-claiming creates social friction.

### Failure modes

- **Tickets that should be split into 3** — agent tries to do all 3, scope explodes. Mitigation: in plan-mode, if the plan touches > ~6 files or > ~300 lines, propose a split first.
- **Stale tickets** — description was written 4 months ago, code has moved. Mitigation: agent compares ticket date to last touched date of mentioned files. If mismatch > 30 days, flag for human verification.

### Per-stack notes

No stack difference. The MCP is the same.

---

## Stage 2 — Plan mode (human gate #1)

### What happens

1. Agent calls `EnterPlanMode`. In plan mode, **no Edit/Write/Bash-side-effect tools are available** — it can read, search, and grep but not change anything.
2. Agent explores the codebase: greps for existing patterns, reads CLAUDE.md, reads relevant tests.
3. Agent drafts a plan and calls `ExitPlanMode`, which surfaces the plan as a confirmation prompt.
4. **You** approve, edit, or reject. If you reject, the agent stays in plan mode and revises.

### What a good plan contains

- Files it will create / modify / delete, with rough line counts and a 1-line purpose.
- Test strategy: which tests to add, which existing tests to extend, which to keep unchanged.
- Risks and open questions: things it's not sure about, with the assumption it's making.
- Out-of-scope list: things it noticed but won't touch in this PR.
- Estimated complexity: small / medium / large.

### Best practices

- **Treat the plan like a design doc, not a TODO list.** Reviewing 10 bullet points takes 30 seconds; if the plan can't fit in 30 seconds of reading, it's too vague.
- **Reject early.** If the first plan is off, fix the framing now — it's much cheaper than fixing code later.
- **Plan should reference CLAUDE.md.** *"Per CLAUDE.md §Repository conventions, I will put the new test under tests/auth/ alongside the existing token test."* Plans that don't cite conventions are a sign the agent didn't read them.
- **Don't skip plan-mode just because the task feels small.** "Just rename a field" turns into a 40-file blast radius surprisingly often.

### Failure modes

- **Over-detailed plan that's actually code in prose form** — defeats the purpose. The plan is for *aligning on direction*, not pre-writing the code.
- **Plan looks good, code diverges** — happens when agent loses context partway through. Mitigation: agent re-reads the plan after every ~20 minutes of work and confirms it's still tracking.

### Per-stack notes

No stack difference, but heuristics for "this needs a plan":

| Stack    | "Needs plan" threshold |
| -------- | --------------------- |
| Node     | > 1 file or any change to a public exported API |
| .NET     | > 1 project or any change to a `public` type signature |
| Next.js  | Any new route segment, any change to data layer, any new server action |

---

## Stage 3 — Develop with guardrails

### What happens

1. Agent creates (or you create) a worktree branch: `gh issue develop PROJ-123 --checkout` or `git switch -c PROJ-123/short-slug`. With `EnterWorktree`, Claude operates on an isolated copy.
2. Agent reads existing patterns first, then writes code.
3. **Hooks fire automatically** on every `Edit`, `Write`, or `Bash` tool call (configured in `.claude/settings.json`). The agent cannot turn them off.
4. Format runs on save. Lint runs after edit. Secret scan blocks credential leaks. Forbidden-paths block edits to off-limits files.

### What the hooks enforce (and why each matters)

| Hook | When | What it blocks | Why |
| --- | --- | --- | --- |
| Format | After each Edit/Write | n/a — just rewrites file | Keeps diffs clean; agent doesn't waste time on style |
| Secret scan | Before each Edit/Write | Writes containing keys/tokens | Stops the most common credential-leak failure mode |
| Forbidden paths | Before each Edit/Write | Edits to `.env`, `migrations/`, `infra/`, etc. | Some files require human change-control |
| Commit gate | Before `git commit` | Commit if any check fails | One-shot enforcement of test + lint + typecheck |
| Stack-specific | Varies | Varies (e.g. block new `pages/` in Next.js App Router repo) | Encodes team-specific conventions as enforcement, not docs |

### Best practices

- **Hooks > documentation > agent judgement.** Documented rules drift; hooks don't.
- **Make hooks fast.** A 30-second hook fires on every edit — that's brutal. Run only fast checks (format, secret scan) per-edit; run the heavy stuff (full test suite) at commit time only.
- **Allow-listing > deny-listing for permissions.** The templates allow specific commands rather than denying dangerous ones — easier to reason about.
- **`Bash(git push --force:*)` is denied.** If you want force-with-lease occasionally, you'll get a confirmation prompt — that's the right friction.
- **Read CLAUDE.md aloud during onboarding.** If it doesn't make sense to a human, the agent won't follow it either.

### Failure modes

- **Hook that's flaky** — exits non-zero intermittently, agent gets stuck. Mitigation: hooks that depend on external services (e.g. *"call lint server"*) are bad; prefer local-only checks.
- **Hook output that's so noisy the agent can't see real errors** — pipe verbose output to a log file, only surface failures.
- **Agent that "fixes" tests by weakening assertions** — happens when agent has access to test files and is rewarded only for green. Mitigation: review subagent (stage 5) reads test diffs and calls this out.

### Per-stack notes

- **Node:** format/lint/secret hooks are JS scripts (`*.mjs`) — same runtime as the project, no extra deps.
- **.NET:** hooks are PowerShell (`*.ps1`) on Windows; `pwsh` is cross-platform so they work in CI/Mac too.
- **Next.js:** adds a third hook to block new files under `pages/` (App-Router-only repos).

---

## Stage 4 — Test

### What happens

1. Agent writes tests alongside or before the feature.
2. Agent runs `npm test` / `dotnet test` / `pnpm test`.
3. Pre-commit hook runs **the full check** (typecheck + lint + format + tests + sometimes build).
4. If anything fails, commit is blocked.

### Best practices

- **TDD when the AC has measurable behavior.** Write the test, watch it fail, write the code, watch it pass. This is the single biggest reason agents produce working code on the first try.
- **Lock the test command in the hook config**, not in CLAUDE.md. CLAUDE.md is for the agent; hook config is for *enforcement*. The agent can re-read CLAUDE.md and decide to skip; it cannot decide to skip a hook.
- **Coverage gate at the file level, not the project level.** Project-level gates are gamed easily (add tests for trivial getters). File-level: *"changed files in this PR must have ≥80% line coverage"* is the version that matters.
- **Don't mock the database.** Use a test container (Postgres in Docker, SQL Server LocalDB, etc.). Mocks pass while the real query has a typo.

### Failure modes

- **Tests that take 10+ minutes** — agent stops running them, just commits and pushes. Mitigation: split into unit (fast, every commit) and integration (slower, every push).
- **Test suite that depends on the order tests run** — agent reruns and gets different results. Mitigation: randomize test order in CI; if it fails when randomized, fix the test.
- **Tests against the agent's own code that pass trivially** — `expect(true).toBe(true)`. Mitigation: review subagent looks for assertion patterns that don't actually assert anything about the code under test.

### Per-stack notes

| Stack    | Unit tests              | Integration / e2e               |
| -------- | ----------------------- | ------------------------------- |
| Node     | Vitest                  | Vitest + testcontainers / supertest |
| .NET     | xUnit + FluentAssertions| xUnit + WebApplicationFactory + Testcontainers |
| Next.js  | Vitest + React Testing Library | Playwright (browser) with `axe-core` for a11y |

---

## Stage 5 — Self-review

### What happens

1. Agent runs `/review` — spawns a code-reviewer subagent on the diff.
2. Agent runs `/security-review` — spawns a security-focused subagent on the diff.
3. Subagents produce a markdown report. The main agent reads it.
4. Main agent either addresses each finding or pushes back with justification.
5. Loop until clean (typically 1–2 rounds).

### Best practices

- **Two reviewers, two perspectives.** The code reviewer cares about correctness, naming, duplication. The security reviewer cares about authn/authz, injection, secret handling. Don't merge them — they pull in different directions.
- **Independent context.** Subagents start fresh; they don't see the agent's reasoning. That's the point — they read the diff like a stranger would.
- **Disagreement is OK.** If the agent pushes back on a finding with a good reason, surface that to you. Don't silently drop findings or silently accept all of them.

### Failure modes

- **Reviewer rubber-stamping** — happens when the diff is huge and the reviewer skims. Mitigation: cap diffs at ~400 lines; bigger PRs get split.
- **Reviewer that nitpicks naming forever** — the loop never converges. Mitigation: 2 review rounds max; after that, surface remaining items to you instead of looping.

### Per-stack notes

No stack difference — the review subagents adapt to the diff's language.

---

## Stage 6 — PR + GitHub + CI loop

### What happens

1. Agent pushes the branch: `git push -u origin PROJ-123/...`.
2. Agent creates a draft PR: `gh pr create --draft --title "..." --body "..."`.
   - Body includes: ticket key + link, plan summary, what changed, test results, any unresolved review findings.
3. CI runs.
4. If you've started `/loop "/check-ci PROJ-123"` (or similar), agent polls `gh pr checks` every ~270 seconds.
5. On failure: agent fetches `gh run view <id> --log-failed`, diagnoses, fixes, pushes again.
6. On green: agent promotes the PR from draft to ready-for-review, posts a comment summarizing CI, and **stops**.

### Best practices

- **PR description as a contract.** Includes the ticket key (auto-links in Atlassian), the plan, the diff highlights, the test/review state. If a reviewer can't review without opening the diff, the description is too thin.
- **Draft PRs are free.** Push early, even if not ready — preview CI runs catch bugs while the agent is still in context.
- **Conventional Commits** so changelog tooling works for free downstream.
- **Cap auto-retries.** 3 attempts at fixing the same CI failure; after that, escalate to a human. Agents that loop forever on a flaky integration test are net-negative.

### Failure modes

- **Flaky CI** — agent burns hours fixing tests that flake randomly. Mitigation: detect "this exact test flaked once on retry" and skip the fix loop.
- **Auto-merge** — never let the agent merge. Always a human gate.

### Per-stack notes

CI YAML differs per stack (see each template's `.github/workflows/ci.yml`). The agent's interaction with `gh` is identical across stacks.

---

## Stage 7 — Merge / deploy (human territory)

### What happens

In plan-gated mode (the default), the agent does **not** click merge. After CI is green:

1. Agent comments on the PR with a summary: *"CI green. Review findings addressed (link). 12 lines added, 4 removed. Ready for human review."*
2. Agent updates the Jira ticket to **In Review** and posts a comment with the PR link.
3. **You** review, approve, and merge.
4. After merge, you (or a deploy bot) deploy.
5. Optionally, the agent can transition Jira to **Done** *after* you confirm deploy success.

### Best practices

- **Don't let the agent close tickets.** Tickets are closed by the people who confirm the value was delivered.
- **One PR, one ticket.** If during work you find a separate bug, file a new ticket. Don't bundle.
- **Post-merge cleanup is a separate ticket.** Delete the worktree, archive review reports — fine for the agent to suggest as a follow-up, not to do silently.

### Failure modes

- **Drift between merged code and ticket** — code shipped, ticket says "in progress" forever. Mitigation: a separate `/sync-jira` slash command runs nightly to catch this.
- **Agent transitioning ticket to Done before you've verified** — never let it. Lock that transition behind a human action.

### Per-stack notes

Deploy mechanism varies (Vercel auto, Azure App Service via GitHub Action, etc.) but the *plan-gated* boundary doesn't.

---

## Putting it all together

The full loop on a healthy day:

| Stage | Time | Who acts |
| --- | --- | --- |
| Jira intake | ~30s | Agent |
| Plan | ~2–5 min | Agent drafts, human approves |
| Develop | ~10–40 min | Agent, hooks enforcing |
| Test | (in develop) | Agent + hooks |
| Review | ~2 min | Subagents |
| PR + CI loop | ~5–15 min | Agent, polling |
| Merge | ~30s | **Human** |

Total: half an hour to an hour for a typical small-medium ticket, most of which you're free to do other work during.

The wins compound: every ticket worked this way teaches the agent (via CLAUDE.md updates and feedback memories) what *this team* values, so the next ticket needs less hand-holding.
