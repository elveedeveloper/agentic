# Agentic Dev Workflow Templates

Ready-to-drop-in templates and docs for running a **full agentic AI development loop** — Jira ticket → plan → develop → guard → test → review → GitHub PR → CI — across multiple stacks.

## What's in here

```
templates/
  node/        Node.js + TypeScript (CLI / library / backend service)
  dotnet/      .NET (C# class lib / Web API / Worker)
  nextjs/      Next.js (App Router, Vitest + Playwright)
docs/
  workflow.md         Full walkthrough of the 7-stage agentic loop
  hooks-cookbook.md   Hook patterns + per-stack recipes
  best-practices.md   Cross-cutting principles you'll reuse on every repo
```

Each template ships with:

**Tier 1 — Local agent (you use these from day one):**
- `CLAUDE.md` — tells the agent the stack conventions, commands, and out-of-scope rules
- `.claude/settings.json` — hook configuration that enforces guardrails (format, lint, test, secret-scan) regardless of agent judgement
- `.github/workflows/ci.yml` — CI pipeline matching what the local hooks enforce
- Stack-specific tooling files (`.editorconfig`, `tsconfig.json`, etc.)

**Tier 2 — Background agents (opt in when ready):**
- `.github/workflows/claude-review.yml` — auto-runs `/review` + `/security-review` on every PR open, posts findings as a PR comment
- `.github/workflows/claude-pr-bot.yml` — wakes Claude when a human comments `@claude ...` on a PR
- `.github/workflows/claude-from-jira.yml` — Jira `agent-ready` label triggers an autonomous draft PR via `repository_dispatch`

Read [docs/industry-context.md](docs/industry-context.md) for what each tier actually is and when each is worth turning on.

## How to use a template

1. Pick the stack folder that matches your repo: `node`, `dotnet`, or `nextjs`.
2. Copy `CLAUDE.md`, `.claude/`, and (if you want CI) `.github/` into your project root. Merge or rename existing files as needed — don't blindly overwrite.
3. Open `CLAUDE.md` and edit the **`<<EDIT ME>>`** placeholders to match your repo (test command, build command, paths, etc.).
4. Open Claude Code in that repo. The agent will read `CLAUDE.md` on startup; hooks fire automatically once `.claude/settings.json` is in place.
5. Run `/init` if you want Claude to flesh out the CLAUDE.md further based on your actual code.

## The agentic loop in one diagram

```
   Jira ticket (Atlassian MCP)
         │
         ▼
    Plan mode  ── human gate #1 ──▶ approved
         │
         ▼
   Worktree branch
         │
   ┌─────┴─────┐
   ▼           ▼
 Edit code   Hooks fire on every Edit/Write/Bash:
   │           - format
   │           - lint
   │           - secret-scan
   │           - forbidden-path check
   ▼
 Tests (locally — blocked at commit hook if red)
         │
         ▼
 /review + /security-review subagents
         │
         ▼
 gh pr create → CI runs
         │
   /loop polling CI ── fix-and-push until green
         │
         ▼
   Human gate #2: merge & deploy
```

## Where to start

If you're new to this:

1. Read [docs/industry-context.md](docs/industry-context.md) to understand what big AI companies actually do and where you fit.
2. Read [docs/workflow.md](docs/workflow.md) for the full 7-stage walkthrough.
3. Skim [docs/best-practices.md](docs/best-practices.md) for the principles.
4. Drop a Tier-1 template into your real repo and try one small ticket end-to-end.
5. Tune hooks via [docs/hooks-cookbook.md](docs/hooks-cookbook.md) once you know what friction you actually hit.
6. Use [docs/ci-babysitter.md](docs/ci-babysitter.md) to keep Claude watching CI while you do other work.
7. Layer in Tier-2 workflows (review → pr-bot → from-jira) one at a time, once Tier 1 feels solid.

## Prereqs

- **Claude Code** installed and authenticated.
- **Git**.
- **`gh` CLI** authenticated to your GitHub account (for the PR stage).
- **Atlassian MCP connector** authenticated (for Jira intake) — run the auth flow from inside Claude Code.
- The stack toolchain for whichever template you use: Node 22+ / .NET 8+ / etc.

## Secrets and Tier-2 setup

The Tier-2 workflows only work after you add a few secrets and (for the Jira flow) a Jira automation rule.

### GitHub repo secrets

| Secret | Used by | What it is |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | All 3 Tier-2 workflows | Your Anthropic API key. Console → Settings → API keys → Create. |
| `PR_BOT_TOKEN` *(optional)* | `claude-pr-bot.yml` | Fine-grained PAT with `contents:write` + `pull-requests:write` on the repo. Without it, `claude-pr-bot` falls back to `github.token` and **cannot** trigger downstream workflows (e.g., your CI won't re-run automatically after Claude pushes). |
| `JIRA_DISPATCH_PAT` *(optional)* | `claude-from-jira.yml` | Same shape as `PR_BOT_TOKEN`. Same reason. |

Add them via **Repo → Settings → Secrets and variables → Actions → New repository secret**.

### Jira automation rule (one per project, only if you want `claude-from-jira`)

In Jira: **Project settings → Automation → Create rule**.

1. **Trigger:** `Label added` — label = `agent-ready`.
2. **Action:** `Send web request`.
   - URL: `https://api.github.com/repos/<OWNER>/<REPO>/dispatches`
   - Method: `POST`
   - Headers:
     - `Authorization: token <PAT_WITH_REPO_DISPATCH_PERMISSION>`
     - `Accept: application/vnd.github+json`
   - Body:
     ```json
     {
       "event_type": "jira-ticket-ready",
       "client_payload": {
         "ticket_key": "{{issue.key}}",
         "summary":    "{{issue.summary}}",
         "description":"{{issue.description}}"
       }
     }
     ```
3. **Save & enable.**

Now: label any ticket `agent-ready` → GitHub Action runs → draft PR appears in the matching repo.

> **Recommendation:** start by enabling `claude-review.yml` only (no secrets risk, low cost, high signal). Add `claude-pr-bot.yml` after a week. Only wire `claude-from-jira.yml` after several weeks of clean Tier-1 history — autonomous PRs amplify both the wins and the mistakes.

### Version pinning

Each workflow uses `anthropics/claude-code-action@v1` with a `# VERIFY current tag` comment. Before enabling in production:

1. Check the [action's releases](https://github.com/anthropics/claude-code-action) for the latest stable tag.
2. Replace `@v1` with that tag (or a pinned commit SHA for maximum stability).
3. Commit the pin.

Don't trust version tags from a Friday-written template (this one) in production — supply-chain hygiene is worth 30 seconds of verification.
