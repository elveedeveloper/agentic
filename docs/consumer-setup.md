# Consumer Setup — Using Agentic as Shared Config Source

> **Audience:** anyone with a real product repo who wants to wire it up to the agentic dev workflow. This is the "big-company shape" — your repo *consumes* shared config from `elveedeveloper/agentic` rather than copy-pasting the templates.

## The model

```
elveedeveloper/agentic                     ←  source of truth (this repo)
├── .github/workflows/
│   ├── reusable-ci-dotnet.yml             ←  shared CI logic; consumers call via workflow_call
│   ├── reusable-claude-review.yml         ←  shared Tier-2 PR review
│   └── reusable-claude-pr-bot.yml         ←  shared Tier-2 @claude bot
├── templates/<stack>/                     ←  source of CLAUDE.md + hooks (copied once at init)
└── scripts/init-claude-config.ps1         ←  the bootstrap tool

your-org/your-product-repo                 ←  the consumer
├── CLAUDE.md                              ←  initialized from agentic, then locally edited
├── .claude/settings.json + hooks/         ←  initialized from agentic, kept fresh via re-init
└── .github/workflows/ci.yml               ←  ~10 lines, calls agentic's reusable-ci-*
```

**Two things are shared, two are local:**

| What | Shared how | Update mechanism |
| --- | --- | --- |
| **CI / Tier-2 workflows** | `workflow_call` from your consumer's `ci.yml` | Automatic — consumer's CI re-runs against Agentic's latest at the pinned ref |
| **Hooks** (guard-commit, guard-secrets) | One-time copy at init | Re-run `init-claude-config.ps1 -Force` to refresh |
| **CLAUDE.md** | One-time copy at init | Per-repo edits are *expected*; the template is just a starting point |
| **`.claude/settings.json`** | One-time copy at init | Per-repo permissions adjustments are *expected* |

This is the lightweight version of the "shared config package" pattern. The proper next step is to extract hooks into a NuGet/npm package; until you have ~3+ consumer repos, that's overkill.

## Bootstrapping a new consumer repo

Prerequisite: you have **a local clone of `elveedeveloper/agentic`** (this repo).

### Step 1 — Create the consumer repo

```powershell
# Create on GitHub
gh repo create your-org/your-product-repo --private --clone

# Or, if it already exists, just clone it
gh repo clone your-org/your-product-repo d:\path\to\your-product-repo
```

### Step 2 — Run the init script from inside the Agentic checkout

```powershell
cd d:\Elvee\repository\Agentic
.\scripts\init-claude-config.ps1 `
    -Target d:\path\to\your-product-repo `
    -Stack dotnet
```

This drops the following files into the target:

| File | Source | What it is |
| --- | --- | --- |
| `CLAUDE.md` | `templates/dotnet/CLAUDE.md` | Verbatim copy; you'll edit `<<EDIT ME>>` placeholders next. |
| `.claude/settings.json` | `templates/dotnet/.claude/settings.json` | Permissions + hook bindings. |
| `.claude/hooks/guard-commit.ps1` | `templates/dotnet/.claude/hooks/guard-commit.ps1` | Pre-commit gate (format/build/test). |
| `.claude/hooks/guard-secrets.ps1` | `templates/dotnet/.claude/hooks/guard-secrets.ps1` | Pre-Edit/Write scan for credentials. |
| `.github/workflows/ci.yml` | *generated* | ~30 lines, calls `reusable-ci-dotnet.yml@main`. |

Existing files in the target are **skipped by default**. Pass `-Force` to overwrite (use carefully — this clobbers per-repo CLAUDE.md edits).

### Step 3 — Resolve `<<EDIT ME>>` placeholders in CLAUDE.md

Open the new `CLAUDE.md`. Search for `<<EDIT ME>>`. Don't stop until there are zero matches. These are the spots where the template can't know your repo's specifics:

- Test runner choice (xUnit vs NUnit vs MSTest)
- Project name for `dotnet run`
- Paths the agent must not touch (`infra/`, `db/migrations/`, etc.)

### Step 4 — `.NET` only: ensure `global.json` exists

The reusable CI uses `global.json` to pin the .NET SDK version. Add one at the repo root if missing:

```json
{
  "sdk": {
    "version": "8.0.412",
    "rollForward": "latestFeature"
  }
}
```

### Step 5 — Commit and push

```powershell
git add CLAUDE.md .claude .github/workflows/
git commit -m "chore: bootstrap agentic dev workflow"
git push
```

The first push triggers the CI workflow. On GitHub Actions you should see the `check` job running, and inside it you'll see *"Called workflow: elveedeveloper/agentic/.github/workflows/reusable-ci-dotnet.yml@main"* — that's the shared config in action.

### Step 6 — Smoke test

Before announcing it to the team, drive **one tiny ticket** through the loop. Same shape as `apps/hello/specs/AGENT-1.md`:

1. Author a spec file (`specs/PROJ-1.md` or similar) describing a trivial change.
2. Branch, plan-mode, write a test, make it green, commit (commit-gate hook fires), push.
3. Open a draft PR; if you've enabled Tier-2, the auto-review fires.
4. Capture a first-run report — note every place the hook misfired or the agent went off-spec.
5. **Tune before running a second ticket.**

## Enabling Tier-2 (auto-review + @claude PR bot)

After Tier-1 has run cleanly on a few stories, you can enable the Tier-2 workflows. Two options:

### Option A — Re-run the init script with `-WithTier2`

```powershell
.\scripts\init-claude-config.ps1 -Target d:\path\to\your-product-repo -Stack dotnet -WithTier2
```

This generates two more workflow shims:

- `.github/workflows/claude-review.yml` — calls `reusable-claude-review.yml@main` on PR open/sync.
- `.github/workflows/claude-pr-bot.yml` — calls `reusable-claude-pr-bot.yml@main` when someone comments `@claude` on a PR.

### Option B — Add the shims by hand

If you've customized your existing CI files, you may prefer to merge by hand. The reusable workflows have caller pattern examples in their YAML header comments — paste those into your consumer.

### Required secrets for Tier-2

Both Tier-2 workflows require GitHub repo secrets:

| Secret | Required by | What |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | both | Your Anthropic API key. Anthropic Console → Settings → API keys. |
| `PR_BOT_TOKEN` | pr-bot only, optional but recommended | Fine-grained PAT with `contents:write` + `pull-requests:write` on this repo. Without it, Claude's pushes via the bot **won't retrigger downstream CI**. |

Add via **Repo → Settings → Secrets and variables → Actions → New repository secret**.

## Enabling Tier-2 autonomous (Jira label → draft PR)

This is the **fully autonomous** branch of Tier-2. A PM (or you) labels a Jira ticket `agent-ready`; Jira fires a webhook to GitHub; a GitHub Actions runner spins up; Claude reads the ticket, plans, codes, tests, and opens a draft PR — no human in the loop until the PR review. Only enable this after Tier-1 has run cleanly on several stories and you're comfortable with the agent's behavior.

**Currently implemented for the `node` stack only.** `dotnet` is a planned follow-up (`reusable-claude-from-jira-dotnet.yml`).

### Wire it up

```powershell
.\scripts\init-claude-config.ps1 -Target d:\path\to\your-product-repo -Stack node -WithFromJira
```

This generates `.github/workflows/claude-from-jira.yml` in your consumer (~25 lines), triggered on `repository_dispatch: types: [jira-ticket-ready]` and delegating to the reusable in Agentic.

### Required repo secrets

| Secret | What |
| --- | --- |
| `ANTHROPIC_API_KEY` | Required. Your Anthropic API key. |
| `JIRA_DISPATCH_PAT` | Optional but recommended. Fine-grained PAT with `contents:write` + `pull-requests:write` on this repo. Without it, Claude pushes as `github.token` and **downstream CI won't retrigger**. |

### Jira automation rule (one per Jira project)

Set up once. In Jira: **Project settings → Automation → Create rule**.

1. **Trigger:** *Label added* — label value: `agent-ready`.
2. **Action:** *Send web request*.
   - **URL:** `https://api.github.com/repos/<OWNER>/<CONSUMER-REPO>/dispatches`
   - **Method:** `POST`
   - **Headers:**
     - `Authorization: token <ATLASSIAN_AUTOMATION_PAT>` — a GitHub fine-grained PAT scoped to that one consumer repo, with at least `metadata:read` + `contents:read`. (This PAT is stored *inside Jira* on the automation rule, not in GitHub.)
     - `Accept: application/vnd.github+json`
   - **Body:**
     ```json
     {
       "event_type": "jira-ticket-ready",
       "client_payload": {
         "ticket_key":  "{{issue.key}}",
         "summary":     "{{issue.summary}}",
         "description": "{{issue.description}}"
       }
     }
     ```
3. **Save & enable.**

To target multiple consumer repos from one Jira project, either (a) put the repo URL behind a smart-value branch on issue type/component, or (b) duplicate the rule per target repo. For one-project-one-repo (the common case), one rule is enough.

### Testing it

1. In Jira, create a small test ticket in the project — e.g., "Add `square(n)` helper that returns `n * n`".
2. Label it `agent-ready`.
3. Watch GitHub Actions on the consumer repo. The `claude-from-jira` workflow should start within ~30 seconds.
4. ~5–15 minutes later: a draft PR appears with branch name `<TICKET-KEY>/<slug>`, opened by `claude-bot`.

### Hard limits the reusable workflow enforces

The reusable's prompt to Claude includes hard rules that **cannot** be overridden by the ticket text:

- DRAFT PR only — never marks ready-for-review.
- Never merges.
- Never force-pushes.
- Never modifies `.github/workflows/`.
- Bails out (opens an empty draft) when ticket scope is genuinely too large (>2 areas of the codebase or >400 lines estimated).

If a ticket needs more than that, escalate to a human via a comment instead of agent-implementing.

### Cost ceiling

A typical small ticket (add an endpoint, fix a bug, dependency bump) runs roughly $0.50–$3 in Anthropic API cost. There's no enforced cap in the workflow yet — if you want one, the Anthropic Console lets you set per-key budget alerts. Per the [Phase 1 first-run report](first-run-report.md), this is worth wiring in when consumer count grows past 2–3.

## Pinning and versioning

By default the generated workflow shims point at `@main`:

```yaml
uses: elveedeveloper/agentic/.github/workflows/reusable-ci-dotnet.yml@main
```

This is the **easy mode** — every CI run uses the latest Agentic. The risk: a bad commit to Agentic's `main` breaks every consumer's CI at once. Fine while you have 1–2 consumers and you're the only one editing Agentic.

**When you have 3+ consumer repos**, switch to tagged versions:

1. In Agentic, tag a release: `git tag -a v1 -m "First stable shared-config release" && git push origin v1`.
2. Re-run the init script with `-AgenticRef v1` against each consumer.
3. Consumer CIs now pin to `@v1`. Updates require a deliberate `-AgenticRef v2` re-init.

## Updating consumers when Agentic changes

| If Agentic changed... | What you need to do in consumers |
| --- | --- |
| Only `.github/workflows/reusable-*.yml` | **Nothing** if pinned to `@main`. If pinned to a tag, retag in Agentic and re-init consumers with the new ref. |
| `templates/<stack>/CLAUDE.md` | Re-run init with `-Force` on consumers — but **diff first**: per-repo edits will be clobbered. Merge by hand more often than not. |
| `templates/<stack>/.claude/hooks/*` | Re-run init with `-Force`. Hooks are usually less repo-customized so `-Force` is safe. |
| `templates/<stack>/.claude/settings.json` | Re-run init with `-Force`, but **diff first** — repos often add their own `permissions.allow` entries. |

## Limitations of this lightweight model

Honest list of what this pattern doesn't give you, and when to upgrade:

- **No central tracking of "which consumers are on which version".** Once 5+ repos, build a simple inventory (a `consumers.yml` in Agentic listing each repo + its pinned ref).
- **Hook updates require a manual re-init per repo.** Once 10+ repos, extract hooks into a NuGet/npm package so they update via `dotnet restore` / `npm install`.
- **No automated tests for the shared workflows themselves.** Once Agentic is hit by 5+ consumers, add a test consumer repo that runs the reusable workflows on every PR to Agentic.

These are real follow-up tickets, not blockers. Start lightweight; extract under pressure when scale demands it.

## Troubleshooting

- **`Error: Unable to find reusable workflow file`** on the consumer's CI — usually means the `uses:` ref is wrong, the Agentic repo is private and the consumer org can't see it, or the file path moved. Check the exact URL: `https://github.com/elveedeveloper/agentic/blob/main/.github/workflows/reusable-ci-dotnet.yml`.
- **Reusable workflow runs but can't read secrets** — confirm the consumer's `secrets:` block explicitly forwards `anthropic-api-key`. Reusable workflows do *not* inherit secrets by default.
- **`global.json` missing → setup-dotnet fails** — add a minimal `global.json` at the consumer's working-directory root, or pass `dotnet-version` as an input to the reusable.
