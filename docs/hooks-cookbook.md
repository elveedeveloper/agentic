# Hooks Cookbook

Hooks are the agentic workflow's hard enforcement layer. They are shell commands the Claude Code harness runs on tool events; the agent cannot opt out of them. Documentation says *what's expected*; hooks make it *true*.

## Anatomy of `.claude/settings.json`

```jsonc
{
  "permissions": {
    "allow": ["Bash(npm:*)"],        // auto-approve these tool calls
    "deny":  ["Bash(rm -rf:*)"]      // hard block these
  },
  "hooks": {
    "PreToolUse":  [ /* fire before the tool runs */ ],
    "PostToolUse": [ /* fire after the tool runs */ ],
    "Stop":        [ /* fire when the agent finishes a turn */ ]
  }
}
```

Each hook entry has:

- `matcher` — string or regex matching the tool name (`Edit`, `Write`, `Bash`, etc.).
- `hooks` — list of `{ "type": "command", "command": "..." }`.

The hook's stdin is JSON describing the tool call (`tool_input`, `tool_name`, etc.). Exit code controls behavior:

| Exit code | Effect |
| --- | --- |
| 0 | Continue normally |
| 2 | **Block the tool call** and surface stderr to the agent |
| other non-zero | Continue but log error |

So: **exit 2 with a clear stderr message** = the agent gets told why it was blocked and can correct.

---

## The four hook patterns you'll always want

### 1. Format-on-edit (PostToolUse, Edit|Write|MultiEdit)

Keeps diffs clean. Runs after every code change.

**Why per-edit, not per-commit?** Because the agent writes prose-like commits and then squashes; intermediate states matter for diffs the agent re-reads while iterating.

**Node:**
```jsonc
{
  "matcher": "Edit|Write|MultiEdit",
  "hooks": [{
    "type": "command",
    "command": "npx --no-install prettier --write $(git diff --name-only --diff-filter=ACMR) 2>nul || exit 0"
  }]
}
```

**.NET:**
```jsonc
{
  "matcher": "Edit|Write|MultiEdit",
  "hooks": [{
    "type": "command",
    "command": "dotnet format --no-restore 2>$null; exit 0"
  }]
}
```

**Next.js:** Same as Node but include `*.css` and use `pnpm exec`.

> **Best practice:** always `|| exit 0` (Bash) / `; exit 0` (PowerShell) for *format* hooks. A format failure shouldn't block the agent — it's cosmetic.

### 2. Secret-scan (PreToolUse, Edit|Write|MultiEdit)

The most important hook. Block the write *before* it touches disk.

**Pattern:** small Node/PS script reads the JSON payload from stdin, greps for known secret patterns in `new_string`/`content`/`edits[].new_string`, exits 2 on match.

See the templates' `guard-secrets.*` for working examples. Patterns to include:

| Pattern | Regex |
| --- | --- |
| AWS access key | `AKIA[0-9A-Z]{16}` |
| AWS secret key | `aws_secret_access_key\s*=\s*['"]?[A-Za-z0-9/+=]{40}` |
| GitHub PAT (classic) | `ghp_[A-Za-z0-9]{36}` |
| GitHub PAT (fine-grained) | `github_pat_[A-Za-z0-9_]{82}` |
| Slack token | `xox[abprs]-[A-Za-z0-9-]{10,}` |
| Stripe live key | `sk_live_[A-Za-z0-9]{24,}` |
| Private key block | `-----BEGIN ... PRIVATE KEY-----` |
| Azure storage key | `AccountKey=[A-Za-z0-9+/=]{60,}` |
| Generic assignment | `(api[_-]?key\|secret\|password)\s*=\s*['"][A-Za-z0-9_\-]{20,}['"]` |
| Next.js public-leak | `NEXT_PUBLIC_[A-Z0-9_]*(SECRET\|KEY\|TOKEN\|PASSWORD)` |

> **Best practice:** if you false-positive on a legitimate constant, **don't weaken the regex** — instead, expose an allowlist comment marker like `// allow-secret-pattern` and have the hook check for it before blocking.

### 3. Commit-gate (PreToolUse, Bash matching `git commit`)

Runs the full quality check before allowing a commit.

```jsonc
{
  "matcher": "Bash",
  "hooks": [{ "type": "command", "command": "node ./.claude/hooks/guard-commit.mjs" }]
}
```

The script inspects `tool_input.command`, only triggers on `git commit`, then runs `npm run check` / `dotnet test` / etc.

> **Best practice:** keep this hook < 60 seconds. If it's slower, agents will start working around it ("let me commit at the end"). Move slow checks (e2e, integration with containers) to CI; keep the commit-gate fast.

### 4. Forbidden-paths

Use the `permissions.deny` list, not a hook — it's faster and clearer:

```jsonc
"deny": [
  "Read(.env)", "Read(.env.*)", "!Read(.env.example)",
  "Write(.env)", "Edit(.env)",
  "Edit(migrations/*)", "Write(migrations/*)"
]
```

The `!` prefix is an exception. The example file is allowed; real env files are not.

---

## Less common but useful hooks

### Stop hook — recap the session

Fires when the agent finishes a turn. Useful to write a session log:

```jsonc
"Stop": [{
  "hooks": [{
    "type": "command",
    "command": "node ./.claude/hooks/log-session.mjs"
  }]
}]
```

The script appends the last user prompt + summary + token usage to `.claude/sessions.log`. Helpful when reviewing what the agent did across a day.

### Pre-merge protection (PreToolUse on Bash, `gh pr merge`)

Block PR merges from inside Claude unconditionally:

```jsonc
"deny": ["Bash(gh pr merge:*)"]
```

The agent can comment, summarize, request review — but cannot merge. This is the lynchpin of plan-gated mode.

### Stack-specific guard: Next.js Pages Router

If your repo is App-Router only, block new files under `pages/`:

```js
// .claude/hooks/guard-pages-router.mjs
const path = JSON.parse(readFileSync(0, 'utf8'))?.tool_input?.file_path ?? '';
if (/[/\\]pages[/\\]/.test(path) && !existsSync(path)) {
  console.error('App Router only. Put new routes under src/app/.');
  process.exit(2);
}
```

> **Pattern:** turn any team rule that gets repeated in PR review into a hook. Repeating yourself in code review is a signal you have a hook-shaped problem.

### Per-language analyzer-as-error (.NET)

Don't use a hook — use `Directory.Build.props`:

```xml
<TreatWarningsAsErrors>true</TreatWarningsAsErrors>
<EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
<AnalysisLevel>latest</AnalysisLevel>
<AnalysisMode>AllEnabledByDefault</AnalysisMode>
```

The build itself becomes the gate; the commit-gate hook just runs `dotnet build`.

### Lint-as-warning vs lint-as-error

In hooks, treat them differently:

- **Format** = silent fix (PostToolUse).
- **Lint warnings** = let through (PreToolUse, exit 0 even if warnings exist).
- **Lint errors** = block at commit-gate.

If you make every lint warning a hard block, agents waste turns chasing stylistic issues that don't matter.

---

## Anti-patterns

- **Don't put business logic in hooks.** Hooks are guards, not orchestrators. If you find yourself writing "if the file is a service, add it to DI registration" in a hook, that belongs in code or CLAUDE.md, not a hook.
- **Don't make hooks depend on network/external services.** Flaky hook = stuck agent.
- **Don't write hook output to stdout.** Use stderr. stdout is reserved for the harness in some hook events.
- **Don't shell out to long-running commands in PreToolUse on Edit/Write.** It fires on every edit; 10s × 50 edits = 8 minutes burned on a single ticket.
- **Don't let hooks accumulate.** Review your `.claude/settings.json` quarterly. Delete hooks that haven't actually caught anything in months — they're paying maintenance cost for no return.

---

## Per-stack quick reference

| Concern | Node | .NET | Next.js |
| --- | --- | --- | --- |
| Hook runtime | `node *.mjs` | `pwsh *.ps1` | `node *.mjs` |
| Format command | `prettier --write` | `dotnet format` | `prettier --write` |
| Pre-commit gate | `npm run check` | `dotnet format --verify-no-changes && dotnet build && dotnet test` | `pnpm check` (incl. `next build`) |
| Allow patterns | `Bash(npm:*)`, `Bash(npx:*)` | `Bash(dotnet:*)` | `Bash(pnpm:*)`, `Bash(npx:*)` |
| Deny env files | `.env`, `.env.*` | `appsettings.*.json` (allow `appsettings.Example.json`) | `.env`, `.env.local`, `.env.production` |
| Special guard | — | — | Block new `pages/` files |
| Lockfile policy | Deny edits | n/a (packages.lock.json optional) | Deny edits to `pnpm-lock.yaml` |

---

## Testing your hooks

After editing `.claude/settings.json`, restart Claude Code so it re-reads. Then verify:

1. **Format hook:** edit a file with bad formatting; confirm it's auto-fixed.
2. **Secret hook:** ask the agent to write `const key = "AKIAIOSFODNN7EXAMPLE";`. Confirm it's blocked with a clear message.
3. **Commit gate:** with intentionally broken code, ask the agent to commit. Confirm block + the underlying error is surfaced.
4. **Forbidden path:** ask the agent to write to `.env`. Confirm the deny rule blocks before the hook even fires.

If any of these don't behave as expected, your hook config is broken — fix before relying on the workflow.
