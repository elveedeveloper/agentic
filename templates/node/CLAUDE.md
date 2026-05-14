# CLAUDE.md — Node.js + TypeScript template

> Drop this file at the **root** of your Node/TS project. Edit `<<EDIT ME>>` placeholders to match reality.

## Stack

- **Runtime:** Node.js 22+
- **Language:** TypeScript (`strict: true`)
- **Test runner:** Vitest
- **Lint:** ESLint (flat config) + `eslint-config-prettier`
- **Format:** Prettier
- **Build:** `tsc -p tsconfig.json` → `dist/`
- **Package manager:** `<<EDIT ME: npm | pnpm | yarn>>`

## Commands the agent must use

| Purpose            | Command                  |
| ------------------ | ------------------------ |
| Install            | `npm ci`                 |
| Run dev            | `npm run dev`            |
| Run unit tests     | `npm test`               |
| Watch tests        | `npm run test:watch`     |
| Coverage           | `npm run test:coverage`  |
| Lint               | `npm run lint`           |
| Auto-fix lint      | `npm run lint:fix`       |
| Format             | `npm run format`         |
| Type-check         | `npm run typecheck`      |
| Full pre-commit check | `npm run check`       |
| Build              | `npm run build`          |

If a command above doesn't exist in `package.json`, **add it before doing the work** — don't invent ad-hoc commands.

## Repository conventions

- Source lives in `src/`. Tests live in `tests/` mirroring the source layout. One test file per source module.
- Public exports are explicit (`index.ts` barrels are fine but no `*` re-exports across module boundaries).
- No `any`. Use `unknown` + narrowing if you need to.
- Logging via `<<EDIT ME: pino | console | other>>`. Never log secrets, tokens, or PII.
- Environment access only through `src/config.ts` (or equivalent). Never `process.env.X` scattered across modules.
- ESM only (`"type": "module"`). Imports use the `.js` suffix even for `.ts` files (NodeNext / Bundler convention).

## Out of scope for the agent

Do **not** modify, rename, or delete:

- `<<EDIT ME: paths the agent must not touch — e.g. infra/, migrations/, generated/>>`
- `.github/workflows/` unless the ticket is explicitly about CI
- Lockfiles (`package-lock.json` / `pnpm-lock.yaml`) — let the package manager regenerate them; don't hand-edit
- Anything inside `node_modules/` or `dist/`

## How the agent should work in this repo

1. **Read the Jira ticket** (via Atlassian MCP) and any linked tickets before planning.
2. **Plan-mode first** for anything > 1 file change. Surface the plan via `ExitPlanMode` for human approval.
3. **One feature per branch.** Branch name: `<key>/<short-slug>` (e.g. `PROJ-123/login-rate-limit`).
4. **Write the test first** when the change has clear acceptance criteria.
5. **Run `npm run check` before committing** — the pre-commit hook also enforces this, but running it manually first surfaces errors faster.
6. **Conventional Commits** for messages: `feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`. Include the ticket key in the subject when relevant: `feat(auth): add rate limit (PROJ-123)`.
7. **Open PR as draft** if any review finding was unresolved or if CI hasn't run yet. Promote to ready-for-review only after CI is green and review subagents agree.

## What `npm run check` runs

```
typecheck  →  eslint  →  prettier --check  →  vitest run
```

If any step fails, the whole thing fails. The commit-time hook runs this; the agent cannot bypass it.

## Notes for future maintainers

This `CLAUDE.md` is part of an agentic dev workflow. Companion files:

- `.claude/settings.json` — automated hooks (format on save, test on commit, secret scan, forbidden paths)
- `.github/workflows/ci.yml` — mirror of the local checks
