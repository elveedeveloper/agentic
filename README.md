# Agentic Dev Workflow

Shared agentic-AI development workflow for **Node.js**, **.NET**, and **Next.js** repos. One source of truth lives here (`elveedeveloper/agentic`); product repos *consume* it via GitHub Actions `workflow_call` + a one-time bootstrap script. The big-company pattern, lightweight enough to run today.

If you're starting fresh: skip to [Quick starts](#quick-starts).
If you already have a real repo: skip to [Adopt on an existing repo](#adopt-on-an-existing-repo).
If you want to know how this is structured: keep reading.

---

## Current state — what's shipped, what's next

| Phase | What it adds | Status |
| --- | --- | --- |
| **1** | Shared-config infrastructure: reusable `ci-dotnet` workflow + `init-claude-config.ps1` + `docs/consumer-setup.md` + Tier-2 (.NET-only) review/pr-bot reusable workflows | ✅ Merged |
| **1.5** | Cleanup: removed `apps/hello` test-bed so Agentic is pure shared-config | ✅ Merged |
| **2** | First real .NET consumer: `elveedeveloper/calculator-api`. CI green via `reusable-ci-dotnet.yml@main` | ✅ Live |
| **3a (Node side)** | Node reusable CI workflow + Node stack support in init script + first Node consumer `elveedeveloper/calculator-api-node` + EL-209 story end-to-end | ✅ Merged |
| **3a (Jira intake)** | Real Jira ticket (`EL-209`) pulled via Atlassian MCP, plan-gated, implemented, reviewed, draft PR, merged | ✅ Merged |
| **3b (autonomous infra)** | Reusable `claude-from-jira-node.yml` + `-WithFromJira` init flag — Node consumers can now get autonomous draft PRs from Jira labels | ✅ Merged (PR #7) |
| **Jira-on-merge infra** | Reusable `jira-on-merge.yml` + `-WithJiraSync` init flag — auto-transition Jira ticket to `Done` when PR merges | 🟡 PR #6 draft, awaiting review |
| **4 (recommended next)** | Live-fire Tier-2 autonomous on a real Jira ticket: wire secrets + Jira automation rule on `calculator-api-node`, label a small ticket `agent-ready`, watch the draft PR appear, capture a first-run report | ⏭️ Next |
| **5** | Stack parity: `reusable-claude-from-jira-dotnet.yml` so `calculator-api` joins the autonomous flow + Node Tier-2 review/pr-bot variants | Future |
| **6** | Production guardrails: CODEOWNERS, branch protection, tag pinning, Anthropic budget alerts | Future |

What you can actually **do today** with what's merged:

- ✅ Stand up a new .NET or Node consumer in under 5 minutes and have it run shared CI.
- ✅ Drive any ticket through a local Tier-1 loop (Claude Code on your machine, agent uses Atlassian MCP for ticket intake).
- ✅ Enable autonomous Tier-2 from Jira → draft PR on Node consumers (after wiring secrets + Jira automation rule).
- 🟡 Auto-transition Jira tickets to Done on merge — *not yet* (PR #6 in flight).
- 🟡 Tier-2 review/pr-bot on Node consumers — *not yet* (.NET only so far).

---

## Where do agents run?

Two distinct locations, two distinct purposes. Most teams use both.

### Local — Tier 1 (you drive)

You open **Claude Code** in your repo, ask it to pick up a ticket, and watch it work. The agent runs on **your machine**. Plan-mode gates surface in your terminal. You approve, edit, or reject before any code lands.

- **Where the work happens:** your laptop / dev VM.
- **Where the API call goes:** Anthropic's API. The agent sends your prompts, file contents in the working set, and tool calls.
- **Where the output lands:** your local git repo, then `git push` to GitHub.
- **What it costs:** Anthropic API tokens for what *you* asked it to do.
- **Best for:** day-to-day feature work, debugging, exploration. Anything you'd want to watch and steer.

### Pipeline — Tier 2 (you're not there)

The same agent, running inside **GitHub Actions** on a Linux runner, triggered by repo events. No human in the loop until the PR review.

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `claude-review.yml` | PR open / synchronize / ready-for-review | Posts an automated `/review` + `/security-review` comment on the PR |
| `claude-pr-bot.yml` | `@claude` comment on a PR | Wakes Claude to address the comment — push code, answer, or both |
| `claude-from-jira.yml` | Jira label `agent-ready` → `repository_dispatch` | Opens a draft PR from scratch based on the Jira ticket |
| `jira-on-merge.yml` | PR `closed` with `merged=true` | Auto-transitions matched Jira tickets to `Done` |

- **Where the work happens:** GitHub-hosted Ubuntu runner (default) or a self-hosted runner if you set one up.
- **Where the API call goes:** Anthropic's API from the runner. Requires `ANTHROPIC_API_KEY` as a GitHub repo secret.
- **Where the output lands:** a branch on your GitHub repo, pushed by the runner's PAT or `GITHUB_TOKEN`.
- **What it costs:** Anthropic API tokens (per-fire) + GitHub Actions minutes. A typical small ticket end-to-end is ~$0.50–$3 in API spend.
- **Best for:** async work that doesn't need your eyes — review-on-open, dependency bumps, after-hours weekend tickets, Jira-driven feature flags. Anything where the human review gate at the *end* of the PR is what matters, not the *start*.

### Best practice — the hybrid model

Most teams that get value from this run **Tier-1 by default, Tier-2 selectively**:

1. Day 1 → Day 90: Tier-1 only. Build muscle memory. Tune `CLAUDE.md` and hooks against your team's actual style.
2. Day 90+: Enable `claude-review.yml` on one repo. Low risk, high signal — comments only, no code pushes.
3. Day 120+: Add `claude-pr-bot.yml` so reviewers can ask `@claude` to fix linting / write a test / explain a hunk.
4. Day 180+ (or never, if you don't need it): `claude-from-jira.yml` for narrow, well-specified ticket types only — dependency bumps, lint fixes, doc updates. Generalist autonomous PRs amplify the agent's worst habits.

Anthropic's hosted alternative — **Claude Code action on a managed runner with no infra** — is what `anthropics/claude-code-action@v1` is. You don't need a self-hosted runner; GitHub's default `ubuntu-latest` works. Self-hosted runners only matter if your code has compliance constraints that forbid running on shared infra.

For the rare team that wants a **fully managed always-on agent** (no GitHub Actions plumbing), Cognition's **Devin** is the comparable commercial product (~$500/mo per seat). What this repo gives you is the same shape, on your own infra, configurable.

---

## Repository layout

```
elveedeveloper/agentic/                  ← this repo (the source of truth)
├── .github/workflows/                   ← reusable workflows called by consumers via workflow_call
│   ├── reusable-ci-dotnet.yml
│   ├── reusable-ci-node.yml
│   ├── reusable-claude-review.yml         (Tier-2 PR review, .NET)
│   ├── reusable-claude-pr-bot.yml         (Tier-2 @claude bot, .NET)
│   ├── reusable-claude-from-jira-node.yml (Tier-2 autonomous, Node)
│   └── reusable-jira-on-merge.yml         (auto-Done on merge — PR #6 in flight)
├── templates/<stack>/                   ← source for CLAUDE.md + hooks (copied once via init script)
│   ├── node/        Node + TS + Vitest + ESLint
│   ├── dotnet/      .NET 8 + xUnit + Roslyn analyzers
│   └── nextjs/      Next.js 14+ App Router + Vitest + Playwright
├── scripts/
│   └── init-claude-config.ps1           ← bootstrap script for consumer repos
└── docs/
    ├── consumer-setup.md                ← full consumer-side guide (you'll read this next)
    ├── workflow.md                      ← 7-stage agentic loop walkthrough
    ├── best-practices.md                ← cross-cutting principles
    ├── hooks-cookbook.md                ← hook patterns + per-stack recipes
    ├── industry-context.md              ← what big AI companies actually do
    └── first-run-report.md              ← findings from the first end-to-end loop validation
```

---

## Two consumption modes

| Mode | What you do | When to pick |
| --- | --- | --- |
| **A — Drop-in** | Copy `templates/<stack>/` into your repo by hand | One-off experiment; you don't care about future updates |
| **B — Shared (recommended)** | Run `init-claude-config.ps1`. Consumer keeps local copies of `CLAUDE.md` + hooks (offline-friendly, per-repo editable); CI logic stays shared via `workflow_call` | Any real repo. Updates to CI flow from one place to all consumers. |

The rest of this README assumes **Mode B**. Mode A is documented in `docs/consumer-setup.md` for reference.

---

## Quick starts

You need: **Claude Code** installed + authenticated, **Git**, **`gh` CLI** authenticated, your stack's toolchain (Node 22+ / .NET 8+ / etc.), and a **local clone of this repo**.

### Quick start — New Node.js + TypeScript project

```powershell
# 1. Create the new GitHub repo (private) + clone alongside Agentic
cd d:\path\to\your-org-repos
gh repo create your-org/your-new-node-app --private --clone

# 2. Scaffold the Node + TS bones (skip if you're starting from an existing project)
cd your-new-node-app
npm init -y
# Drop in your source layout: src/, tests/, .nvmrc with node 22.13.0, etc.

# 3. Wire up agentic shared config
cd d:\path\to\Agentic
.\scripts\init-claude-config.ps1 `
    -Target d:\path\to\your-org-repos\your-new-node-app `
    -Stack node

# 4. Resolve <<EDIT ME>> placeholders in the new CLAUDE.md (search for the markers)
# 5. Add a .gitattributes for LF normalization (see docs/consumer-setup.md "EOL gotcha")

# 6. First commit + push
cd d:\path\to\your-org-repos\your-new-node-app
git add CLAUDE.md .claude .github/workflows/
git commit -m "chore: bootstrap agentic dev workflow"
git push
```

First push triggers CI; you should see the `check` job report *"Called workflow: elveedeveloper/agentic/.github/workflows/reusable-ci-node.yml@main"*. That's the shared CI in action.

Working examples: [`elveedeveloper/calculator-api-node`](https://github.com/elveedeveloper/calculator-api-node).

### Quick start — New .NET 8 project

```powershell
# 1. Create the new GitHub repo (private) + clone
cd d:\path\to\your-org-repos
gh repo create your-org/your-new-dotnet-app --private --clone

# 2. Scaffold .NET 8 (do this BEFORE wiring agentic so global.json drives the new dotnet commands)
cd your-new-dotnet-app
'{ "sdk": { "version": "8.0.400", "rollForward": "latestFeature" } }' | Out-File -Encoding utf8 global.json
dotnet new gitignore
dotnet new editorconfig
dotnet new sln -n YourApp
dotnet new web   -n YourApp.Api       -o src/YourApp.Api       --framework net8.0
dotnet new xunit -n YourApp.Api.Tests -o tests/YourApp.Api.Tests --framework net8.0
dotnet sln YourApp.sln add src/YourApp.Api/YourApp.Api.csproj tests/YourApp.Api.Tests/YourApp.Api.Tests.csproj
dotnet add tests/YourApp.Api.Tests/YourApp.Api.Tests.csproj reference src/YourApp.Api/YourApp.Api.csproj
dotnet add tests/YourApp.Api.Tests/YourApp.Api.Tests.csproj package Microsoft.AspNetCore.Mvc.Testing --version "8.0.*"

# 3. Directory.Build.props (nullable, warnings-as-errors) — see templates/dotnet/Directory.Build.props.example

# 4. Wire up agentic shared config
cd d:\path\to\Agentic
.\scripts\init-claude-config.ps1 `
    -Target d:\path\to\your-org-repos\your-new-dotnet-app `
    -Stack dotnet

# 5. Resolve <<EDIT ME>> placeholders in CLAUDE.md
# 6. Set end_of_line = lf in .editorconfig (see docs/consumer-setup.md "EOL gotcha")

# 7. First commit + push
cd d:\path\to\your-org-repos\your-new-dotnet-app
git add CLAUDE.md .claude .github/workflows/ global.json .gitignore .gitattributes Directory.Build.props YourApp.sln src tests
git commit -m "chore: bootstrap agentic dev workflow"
git push
```

Working example: [`elveedeveloper/calculator-api`](https://github.com/elveedeveloper/calculator-api).

### Quick start — New Next.js project

Reusable CI for Next.js is **not yet implemented**. Path A: use the drop-in template (`templates/nextjs/`) for now. Path B: add `reusable-ci-nextjs.yml` first, similar to `reusable-ci-node.yml`. The CLAUDE.md + hooks are already present in `templates/nextjs/`.

If you go path A:

```powershell
cd d:\path\to\your-new-nextjs-app

# Drop in template files
copy d:\path\to\Agentic\templates\nextjs\CLAUDE.md .
xcopy d:\path\to\Agentic\templates\nextjs\.claude .claude\ /E /I
xcopy d:\path\to\Agentic\templates\nextjs\.github .github\ /E /I

# Resolve placeholders, commit, push.
```

### Adopt on an existing repo

The hard mode — your repo already has CI, ESLint, eslint config, etc. Don't blindly overwrite anything.

**Step 1 — Pick your smallest, lowest-risk repo.** Library, internal tool, low-traffic service. The first adoption is about learning friction, not shipping features.

**Step 2 — Run the init script with conservative defaults:**

```powershell
.\scripts\init-claude-config.ps1 `
    -Target d:\path\to\existing-repo `
    -Stack <node|dotnet|nextjs>
```

By default it **skips** any file that already exists. It will:
- Create `CLAUDE.md` only if not already present.
- Create `.claude/` only if not already present.
- Create `.github/workflows/ci.yml` only if not already present.

If your repo already has a `CLAUDE.md`, the init won't touch it. Merge new content from `templates/<stack>/CLAUDE.md` by hand — *don't* lose your repo-specific conventions.

**Step 3 — Reconcile CI conflicts.** Most existing repos have `.github/workflows/ci.yml` already. Three options:

| Option | When |
| --- | --- |
| **Rename the new file** to `claude-ci.yml` and let both run | Simplest; some duplicate compute |
| **Merge** the agentic CI step into your existing `ci.yml` | Cleaner long-term; more work |
| **Skip** the agentic CI entirely | Your existing CI already runs `npm run check` / `dotnet test` |

The shared-config CI is the *safety net*. Local hooks are what actually enforce per-commit. You can adopt CLAUDE.md + hooks without touching your CI at all.

**Step 4 — Reconcile other tooling.** `.editorconfig`, `tsconfig.json`, `eslint.config.js`, `package.json` scripts — these are **repo-owned**. The init script does not touch them. If the hooks reference commands that don't exist (e.g. `npm run check`), either:
- Add the script to `package.json` (preferred — `check` is a meaningful name).
- Or edit `.claude/hooks/guard-commit.mjs` to call your existing command.

**Step 5 — Smoke test.** Open Claude Code in the existing repo, give it a tiny ticket (typo fix, doc update, one-function helper). Drive end-to-end. Capture a first-run report ([example](docs/first-run-report.md)). Tune **before** running a second ticket.

**Step 6 — Roll out.** Once one repo works cleanly for 5–10 stories, adopt the next one. Don't enable Tier-2 on more than one repo until you've felt the Tier-1 friction first.

---

## Where to tune code quality

Four distinct layers, in order from "vague guidance" to "hard enforcement". When something feels off, ask "which layer is the right fix?"

### 1. `CLAUDE.md` — the contract

What the agent reads at startup. Tell it your stack conventions, your commands, your out-of-scope paths. Per-repo file. Edit freely.

| If you want to... | Edit |
| --- | --- |
| Change which test runner the agent assumes | The "Stack" section |
| Add a new "must" rule (e.g. "all DB queries go through `db/client.ts`") | "Repository conventions" |
| Forbid the agent from touching a path | "Out of scope for the agent" |
| Make the agent always TDD a specific module | "How the agent should work in this repo" |

**Limit:** 200 lines. Past that, you're trying to encode taste — move it to enforcement (next layer) or human review.

### 2. `.claude/settings.json` — permissions + hook bindings

What tools the agent is allowed to use, and which hooks fire on which tool calls. Per-repo. Hard rules (the agent literally cannot do what's in `deny`).

| If you want to... | Edit |
| --- | --- |
| Allow a new shell command without prompting | `permissions.allow` (use specific patterns like `Bash(npm:*)`) |
| Block a dangerous command | `permissions.deny` (e.g. `Bash(rm -rf:*)`) |
| Make a new hook fire on every `Edit` | `hooks.PreToolUse` block |
| Add a forbidden-paths rule | A new hook that exits 2 when a `forbidden/` write is attempted |

### 3. `.claude/hooks/*` — enforcement scripts

The hooks themselves. Per-repo files. These actually run and pass/fail.

| File | When it fires | What it does |
| --- | --- | --- |
| `guard-commit.mjs` (Node) / `.ps1` (.NET) | Before any `Bash(git commit:*)` | Runs the full `npm run check` / `dotnet format && build && test` — blocks if anything fails |
| `guard-secrets.mjs` (Node) / `.ps1` (.NET) | Before any `Edit / Write / MultiEdit` | Scans the new content for AWS keys, GitHub PATs, private key blocks, etc. — blocks if found |
| `guard-pages-router.mjs` (Next.js only) | Before file writes under `pages/` | Blocks new pages-router files in App-Router-only repos |

Customize by editing the script. New regex for new secret types, new path patterns, new conditions.

### 4. Stack tooling — the real quality gate

The agent obeys what the toolchain says. Strict TypeScript, Roslyn analyzers, ESLint, Prettier. **These do the heavy lifting.** Per-repo, edit per the toolchain's docs.

| If you want to... | Edit |
| --- | --- |
| Forbid `any` in TypeScript | `eslint.config.js` rules + `tsconfig.json` `noImplicitAny` |
| Forbid `var` for primitives (.NET) | An analyzer config in `Directory.Build.props` |
| Enforce 100% test coverage on changed files | CI workflow + coverage tool config (coverlet / vitest) |
| Make every PR run an a11y check (Next.js) | Add a Playwright + `axe-core` step in CI |

**Rule of thumb:** if you can express it as a lint rule or compiler flag, do that. Then `CLAUDE.md` only needs to say *"the codebase enforces X via the linter"* — the agent will respect it because the linter will reject otherwise.

For deep-dive patterns, see [docs/hooks-cookbook.md](docs/hooks-cookbook.md) and [docs/best-practices.md](docs/best-practices.md).

---

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
 gh pr create → CI runs (shared workflow_call to Agentic)
         │
   /loop polling CI ── fix-and-push until green
         │
         ▼
   Human gate #2: merge & deploy
         │
         ▼
 jira-on-merge.yml fires → ticket auto-Done
```

Full walkthrough with failure modes and per-stack notes: [docs/workflow.md](docs/workflow.md).

---

## Prereqs

- [**Claude Code**](https://claude.com/claude-code) installed and authenticated.
- **Git**.
- [**GitHub `gh` CLI**](https://cli.github.com/) authenticated to your GitHub account.
- **Atlassian MCP connector** authenticated inside Claude Code (run `/mcp`, select `claude.ai Atlassian`, complete the browser flow). Only needed for Jira intake.
- Your stack toolchain: Node 22+, .NET 8+, or whatever your stack requires.

---

## Secrets cheat sheet

Add at **Repo → Settings → Secrets and variables → Actions → New repository secret** on each consumer.

| Secret | Required for | Where to get it |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | All Tier-2 workflows | Anthropic Console → Settings → API keys → Create Key |
| `PR_BOT_TOKEN` | `claude-pr-bot.yml` (optional but recommended) | GitHub → Settings → Developer settings → Fine-grained tokens. Scope: this repo. Perms: `Contents: Read & write` + `Pull requests: Read & write` |
| `JIRA_DISPATCH_PAT` | `claude-from-jira.yml` (optional but recommended) | Same as `PR_BOT_TOKEN` — separate token so revocation is granular |
| `JIRA_BASE_URL` | `jira-on-merge.yml` | e.g. `https://elvee.atlassian.net` (no trailing slash) |
| `JIRA_USER_EMAIL` | `jira-on-merge.yml` | The Atlassian account whose API token will sign requests |
| `JIRA_API_TOKEN` | `jira-on-merge.yml` | https://id.atlassian.com/manage-profile/security/api-tokens → Create API token |

And one PAT that lives **inside Jira** (not GitHub) on the automation rule that fires `repository_dispatch`: a fine-grained GitHub PAT with `metadata:read` + `contents:read` on the target consumer repo. See [docs/consumer-setup.md](docs/consumer-setup.md#jira-automation-rule-one-per-jira-project) for the full Jira automation recipe.

---

## Versioning

Reusable workflows default to `@main` in generated consumer shims:

```yaml
uses: elveedeveloper/agentic/.github/workflows/reusable-ci-node.yml@main
```

Easy mode. Risky once you have 3+ consumers (a bad commit to Agentic main breaks all CIs at once).

When you have 3+ consumer repos:

1. In Agentic, tag a release: `git tag -a v1 -m "First stable" && git push origin v1`.
2. Re-run the init script per consumer with `-AgenticRef v1`.
3. Updates require a deliberate `-AgenticRef v2` per-repo bump.

`anthropics/claude-code-action` itself is pinned to `@v1` in our reusable workflows with a `# VERIFY current tag` comment — check the [action's releases](https://github.com/anthropics/claude-code-action) before depending on this in production.

---

## Reading order

- **Newcomer:** this file → [`docs/industry-context.md`](docs/industry-context.md) → [`docs/workflow.md`](docs/workflow.md) → quick start above.
- **Adopting on an existing repo:** [`docs/consumer-setup.md`](docs/consumer-setup.md) → [Adopt on an existing repo](#adopt-on-an-existing-repo) above → [`docs/hooks-cookbook.md`](docs/hooks-cookbook.md).
- **Tuning quality:** [Where to tune code quality](#where-to-tune-code-quality) above → [`docs/best-practices.md`](docs/best-practices.md) → [`docs/hooks-cookbook.md`](docs/hooks-cookbook.md).
- **Running CI for your changes to Agentic itself:** [`docs/ci-babysitter.md`](docs/ci-babysitter.md).
- **What went wrong / right the first time we ran this end-to-end:** [`docs/first-run-report.md`](docs/first-run-report.md).
