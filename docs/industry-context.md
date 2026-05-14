# How Big AI Companies Actually Do Agentic Coding (2026)

This is the honest landscape — not marketing slides. Use it to calibrate where you are and what's worth aspiring to.

## TL;DR

| Tier | Who's there | What it looks like | When it's worth building |
| --- | --- | --- | --- |
| **Tier 1 — Local agent** | Most senior devs at Anthropic, OpenAI, Google, top startups | Engineer opens Claude Code / Cursor locally → asks for the next ticket → plan-gated dev → PR → human merge | Now. Cheap to start, fast to learn. |
| **Tier 2 — Background agents** | Cognition (Devin), GitHub Copilot Agents, Cursor Background Agents, Sourcegraph Cody Agents | Issue labeled `agent-ready` → CI runner spins container → agent opens draft PR → humans comment on PR to steer → human merges | Once Tier 1 is muscle memory and you have repeated, well-specified ticket types |
| **Tier 3 — Multi-agent platform** | Anthropic internal teams, OpenAI Codex platform, Replit Agent, Cognition | Lead agent decomposes work, dispatches to planner / coder / reviewer / security specialists in parallel sandboxes | Only with a platform team (3+ engineers full-time on the infra) |

You are starting at Tier 1. The templates and docs in this repo give you a clean Tier 1 setup across .NET / Node / Next.js. The Tier-2 workflow files (`claude-review.yml`, `claude-pr-bot.yml`, `claude-from-jira.yml`) are also included so you can opt in piece by piece.

---

## Tier 1 in detail — what a great solo / small team does

**The workflow:**

1. Engineer at desk. Coffee.
2. Opens Claude Code in the target repo.
3. *"Pick the highest-priority To-Do ticket assigned to me in PROJ."*
4. Agent reads ticket via Atlassian MCP, transitions to In Progress.
5. Agent enters plan mode. Surfaces a plan after 1–2 minutes.
6. Engineer reads the plan in 30 seconds, approves (or pushes back).
7. Agent works: writes test, writes code, runs check, commits. Hooks enforce guardrails on every edit.
8. Agent pushes branch, opens draft PR.
9. Engineer reviews PR (still over coffee).
10. Engineer asks `@claude` in PR comment to fix anything off.
11. Engineer hits Merge.

**Why this works for individual productivity:**
- Engineer stays in flow; agent handles the boring half (boilerplate, test setup, CI back-and-forth).
- Hooks mean the engineer doesn't have to *trust* the agent — they trust the gates.
- Plan-mode means the engineer's mental load is "is this direction right?", not "is every line right?".

**What it doesn't give you:** autonomy while you're not at the keyboard. The agent runs only while you're driving.

**Companies doing this:** Approximately every well-equipped engineering team in 2026. This is table stakes, not differentiation.

---

## Tier 2 in detail — background agents

**The workflow:**

1. PM creates a ticket in Jira, labels it `agent-ready`.
2. Jira automation rule fires a webhook to GitHub.
3. GitHub `repository_dispatch` triggers `.github/workflows/claude-from-jira.yml`.
4. A runner spins up a container, checks out the repo, runs Claude Code headless with the ticket payload.
5. Agent works through the loop *inside the runner* — plans, codes, tests, opens a draft PR. No human involved.
6. Humans get a Slack notification: *"Draft PR opened by Claude agent for PROJ-123."*
7. Humans comment on the PR. Each `@claude` comment triggers `claude-pr-bot.yml` — agent wakes, addresses the comment, pushes more commits.
8. When CI is green and humans are satisfied, a human merges.

**What this gives you that Tier 1 doesn't:**
- Work happens overnight, on weekends, while you're in meetings.
- You can fan out 5 agents on 5 small tickets in parallel.
- Onboarding new hires: they file a ticket; an agent makes the first attempt; the new hire learns by reviewing the agent's PR.

**What it costs:**
- API tokens. A small ticket end-to-end is roughly $0.50–$3 in API spend. Most teams cap per-repo daily budgets.
- Infra: GitHub Actions minutes (or self-hosted runners). Sandbox configuration. Secrets management.
- Investment in `CLAUDE.md` quality. A weak `CLAUDE.md` produces bad Tier-2 PRs that waste human-review time. The ROI flips negative if the agent's PRs need more review than the work itself.

**Real-world Tier-2 platforms:**

| Platform | What it is | Strengths | Caveats |
| --- | --- | --- | --- |
| **GitHub Copilot Agents** | Labeled issue → Copilot opens PR | Tight GitHub integration, no infra to manage | GitHub-only ecosystem; less codebase awareness than dedicated tools |
| **Cognition Devin** | Hosted agent that picks Linear tickets | Best autonomous mode, replayable sessions | Expensive ($500/mo+ per seat); locked to Cognition's runners |
| **Cursor Background Agents** | Cursor-managed agents that work on branches asynchronously | Tight Cursor IDE integration | Cursor IDE required |
| **Anthropic Claude Code + GitHub Actions** | What you're building toward | Full control, your infra, your prompts | You assemble the pieces yourself (this repo) |
| **Sourcegraph Cody Agents** | Agents with deep code-graph context | Best for large monorepos | Enterprise pricing |

**A note on hype:** marketing pages will show fully-autonomous-merging-to-prod demos. In practice, nobody serious does this. Even at Cognition, Devin's PRs land in front of a human. Plan-gated + human-merge is the responsible default.

---

## Tier 3 in detail — multi-agent platforms

This is where it gets research-y. The pattern:

- A **lead agent** receives the work item. Its only job is decomposition and routing.
- Specialized agents do narrow jobs:
  - **Planner** — reads codebase, produces an implementation plan.
  - **Coder** — writes the diff against the plan.
  - **Test-writer** — writes tests against the AC (separately from coder, deliberately).
  - **Reviewer** — reads the diff cold, catches issues.
  - **Security agent** — runs on diffs touching auth/data/secrets.
  - **Doc agent** — keeps CLAUDE.md and READMEs in sync with reality.
- The lead synthesizes outputs and decides when to escalate to a human.

**Who's actually doing this productively?**

- Anthropic's internal eval/agent teams (papers and blog posts about "agentic harnesses").
- Cognition Devin's internal architecture (the user sees one agent, but multiple specialists are coordinating).
- Sweep, Replit Agent — open-ish architectures.
- Most of the rest is research demos.

**Should you build this?** Almost certainly not, at any scale below ~10 engineers. The orchestration overhead eats the gains. Two well-tuned Tier-1 agents (you + one for review) outperform a poorly-orchestrated Tier-3 fleet.

The exception: if you have a **very high volume** of similar small tickets (e.g., dependency bumps, lint fixes, security patches across 200 repos), a narrow Tier-3 setup focused on that one problem class can be huge. Generalist Tier-3 is rarely worth it.

---

## What you should do, in order

Given you're starting from zero:

### Month 1 — Tier 1 fluency
- Use the templates in this repo on your real .NET / Node / Next.js projects.
- Drive 10–20 tickets through the local loop. Notice what trips up the agent.
- After each rough spot: update `CLAUDE.md`, add a hook, or save a feedback memory.
- Goal: feel confident that the agent + hooks + your review produces clean PRs.

### Month 2 — Add `claude-review.yml`
- Drop the auto-review workflow into one repo.
- Every new PR gets `/review` and `/security-review` comments automatically.
- Cheap, high-signal, no autonomy risk.

### Month 3 — Add `claude-pr-bot.yml`
- Now you can comment `@claude please fix the failing eslint error` on a PR and it will.
- Still you-initiated; the agent reacts rather than acts.

### Month 4+ — `claude-from-jira.yml` if it's worth it
- Wire Jira → GitHub dispatch for one specific ticket type (e.g., dependency bumps).
- See if the Tier-2 ROI is real for your team.
- Expand the scope only if month-4 shows real wins.

### Don't aspire to Tier 3
Not until you have a platform team. By the time you do, the tooling will have moved on.

---

## What's in this repo to support each step

| You're doing this | Use this |
| --- | --- |
| Local agentic dev (Tier 1) | `templates/<stack>/CLAUDE.md`, `templates/<stack>/.claude/` |
| Auto-review PRs (early Tier 2) | `templates/<stack>/.github/workflows/claude-review.yml` |
| `@claude` PR bot (mid Tier 2) | `templates/<stack>/.github/workflows/claude-pr-bot.yml` |
| Jira-label → autonomous PR (full Tier 2) | `templates/<stack>/.github/workflows/claude-from-jira.yml` |
| CI babysitting locally | `docs/ci-babysitter.md` |

Set up secrets and Jira automation per the root [`README.md`](../README.md#secrets-and-tier-2-setup).
