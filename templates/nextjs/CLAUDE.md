# CLAUDE.md — Next.js template

> Drop at the **repository root** of your Next.js app. App Router assumed (Next 14+). Edit `<<EDIT ME>>` placeholders.

## Stack

- **Framework:** Next.js 14+ (App Router)
- **Language:** TypeScript strict
- **UI:** `<<EDIT ME: React + Tailwind | shadcn/ui | other>>`
- **Data:** `<<EDIT ME: Server Components + Server Actions | tRPC | REST | etc.>>`
- **Tests:** Vitest (unit/component) + Playwright (e2e)
- **Lint:** `next lint` (ESLint with `next/core-web-vitals`) + Prettier
- **Package manager:** `<<EDIT ME: pnpm (preferred) | npm | yarn>>`

## Commands the agent must use

| Purpose         | Command                            |
| --------------- | ---------------------------------- |
| Install         | `pnpm install --frozen-lockfile`   |
| Dev server      | `pnpm dev`                         |
| Build           | `pnpm build`                       |
| Start prod      | `pnpm start`                       |
| Unit tests      | `pnpm test`                        |
| E2E tests       | `pnpm test:e2e`                    |
| Lint            | `pnpm lint`                        |
| Format          | `pnpm format`                      |
| Type-check      | `pnpm typecheck` (`tsc --noEmit`)  |
| Pre-commit      | `pnpm check`                       |

> `pnpm check` should run: `typecheck → lint → format:check → test → build`.
> Run `build` because `next build` catches type errors that `tsc --noEmit` may miss (especially in route handlers and `generateStaticParams`).

## Repository conventions

- **App Router only.** Pages Router code (`pages/`) is forbidden in new work.
- **Server Components by default.** Use `'use client'` only when you need: state, effects, event handlers, browser APIs, or third-party client libs.
- **Server Actions** for mutations. No fetch-from-client to your own API routes unless there's a specific reason.
- **Co-locate component, styles, tests, and stories** in the same folder.
- **No `next/image` without explicit `width`/`height` or `fill` with sized parent.** Layout shift is a CI failure.
- **Env vars:** server-only via `process.env.X`; client-exposed must be prefixed `NEXT_PUBLIC_`. Access via `src/lib/env.ts` (Zod-validated). Never use `process.env` directly outside that module.
- **No `<a>` for internal links.** Use `next/link`.
- **Metadata:** every route exports `metadata` or `generateMetadata`. SEO/social-tag failures are CI failures.
- **Accessibility:** `eslint-plugin-jsx-a11y` rules are errors, not warnings.

## Out of scope for the agent

Do **not** modify:

- `<<EDIT ME: e.g. middleware.ts auth logic, lib/billing/*, prisma/migrations/*>>`
- `.github/workflows/` unless the ticket is about CI
- `pnpm-lock.yaml` directly — let pnpm regenerate it
- `next.config.{js,mjs,ts}` unless the ticket is about config

## How the agent should work in this repo

1. **Read the Jira ticket** and any linked Figma / docs before planning.
2. **Plan-mode first** for anything that touches more than one route segment, the data layer, or shared UI primitives.
3. **Write a Playwright spec** for any user-facing acceptance criterion *before* writing the route/component.
4. **Run `pnpm check` before committing.** The hook enforces this.
5. **Bundle-size discipline:** if a change adds > 10kB gzipped to a route's First Load JS, mention it in the PR description.
6. **Commit message style:** Conventional Commits — `feat(checkout): add saved-card row (PROJ-123)`.
7. **Preview deploys:** assume Vercel-style preview URLs are generated per PR. Don't try to deploy locally.

## What the commit-time guard runs

```
tsc --noEmit  →  next lint  →  prettier --check  →  vitest run  →  next build
```

The build step is intentional — it catches Next-specific type errors (route handlers, dynamic params) that `tsc --noEmit` skips.

## Performance & a11y guardrails

- Lighthouse CI (or unlighthouse) runs in PR; budget defined in `.lighthouserc.json`.
- Bundle analysis: `pnpm build` with `ANALYZE=true` available locally.
- `axe-core` runs inside Playwright e2e for critical routes.
