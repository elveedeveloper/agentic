# CLAUDE.md — hello (agentic loop test bed)

This is a minimal Node + TypeScript app used to validate the full agentic
development loop end-to-end. Treat it as a real project — same conventions
apply — but the scope is intentionally tiny so friction in the loop itself
is what shows up, not friction in the domain.

## Stack

- **Runtime:** Node.js 22+
- **Language:** TypeScript (`strict: true`)
- **Test runner:** Vitest
- **Lint:** ESLint (flat config) + `eslint-config-prettier`
- **Format:** Prettier
- **Package manager:** npm

## Commands the agent must use

| Purpose               | Command                 |
| --------------------- | ----------------------- |
| Install               | `npm ci`                |
| Run unit tests        | `npm test`              |
| Watch tests           | `npm run test:watch`    |
| Coverage              | `npm run test:coverage` |
| Lint                  | `npm run lint`          |
| Auto-fix lint         | `npm run lint:fix`      |
| Format                | `npm run format`        |
| Type-check            | `npm run typecheck`     |
| Full pre-commit check | `npm run check`         |

If a command above doesn't exist in `package.json`, **add it before doing the work** — don't invent ad-hoc commands.

## Repository conventions

- Source lives in `src/`. Tests live in `tests/` mirroring the source layout. One test file per source module.
- Public exports are explicit. No `*` re-exports across module boundaries.
- No `any`. Use `unknown` + narrowing if you need to.
- ESM only (`"type": "module"`). Imports use the `.js` suffix even for `.ts` files (Bundler convention).
- No logging in this app — it's a pure library. If a future ticket adds logging, route it through `src/lib/logger.ts`; never call `console.log` directly.

## Specs

This app uses the **spec-as-file** convention. Every story has a corresponding
`specs/<TICKET-KEY>.md` checked in alongside the code. The agent reads the spec
file as the durable contract — chat prompts can drift, the spec doesn't.

A spec contains:

- **Summary** — one sentence.
- **Description** — context and motivation.
- **Acceptance criteria** — bullet points, falsifiable.
- **Test strategy** — which tests to add, mirroring which existing patterns.
- **Out of scope** — what the agent must _not_ touch in this story.

## Out of scope for the agent (this app)

Do **not** modify, rename, or delete:

- `package.json`'s `engines`, `scripts.check`, or any devDependency entry unless the ticket is explicitly about tooling
- `.claude/` (hooks and permissions are policy, not feature work)
- Lockfiles (`package-lock.json`) — let npm regenerate them; don't hand-edit
- Anything inside `node_modules/`, `dist/`, or `coverage/`

## How the agent should work in this repo

1. **Read the spec** at `specs/<TICKET-KEY>.md`. If no spec exists, ask before proceeding.
2. **Plan-mode first** for anything > 1 file change. Surface the plan via `ExitPlanMode` for human approval.
3. **One feature per branch.** Branch name: `<key>/<short-slug>` (e.g. `AGENT-1/farewell`).
4. **Write the test first** when the change has clear acceptance criteria.
5. **Run `npm run check` before committing** — the pre-commit hook also enforces this, but running it manually first surfaces errors faster.
6. **Conventional Commits** for messages: `feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`. Include the ticket key in the subject: `feat: add farewell function (AGENT-1)`.
7. **Stop before push** — push and PR creation are human-gated for this test bed until the auth situation is resolved.

## What `npm run check` runs

```
typecheck  →  eslint  →  prettier --check  →  vitest run
```

If any step fails, the whole thing fails. The commit-time hook runs this; the agent cannot bypass it.

## Companion files

- `.claude/settings.json` — automated hooks (format on save, test on commit, secret scan)
- `.claude/hooks/guard-commit.mjs` — runs `npm run check` before any `git commit`
- `.claude/hooks/guard-secrets.mjs` — blocks writes containing common credential patterns
