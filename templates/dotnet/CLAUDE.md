# CLAUDE.md — .NET template

> Drop at the **repository root** (next to your `.sln`). Edit `<<EDIT ME>>` placeholders to match the actual repo.

## Stack

- **Runtime/SDK:** .NET 8 (or 9) — pinned via `global.json`
- **Language:** C# with nullable + implicit usings ON, `TreatWarningsAsErrors=true`
- **Test runner:** `<<EDIT ME: xUnit | NUnit | MSTest>>` (xUnit recommended)
- **Format/lint:** `dotnet format` + Roslyn analyzers (`Microsoft.CodeAnalysis.NetAnalyzers`) + StyleCop optional
- **Build:** `dotnet build -c Release`
- **CI:** GitHub Actions (see `.github/workflows/ci.yml`)

## Commands the agent must use

| Purpose            | Command                                                                |
| ------------------ | ---------------------------------------------------------------------- |
| Restore            | `dotnet restore`                                                       |
| Build              | `dotnet build --no-restore -c Release`                                 |
| Run unit tests     | `dotnet test --no-build -c Release --logger "trx"`                     |
| Coverage           | `dotnet test --collect:"XPlat Code Coverage"`                          |
| Format check       | `dotnet format --verify-no-changes --severity warn`                    |
| Format apply       | `dotnet format`                                                        |
| Analyzers as errors| Already enforced via `Directory.Build.props` (`TreatWarningsAsErrors`) |
| Run app            | `dotnet run --project src/<<EDIT ME: Project.Name>>`                   |

## Repository conventions

- **Solution layout:** `src/<Project>` for production code; `tests/<Project>.Tests` for tests. One test project per production project.
- **One class per file.** Filename matches the public type.
- **`Directory.Build.props` at the solution root** sets shared settings: nullable, implicit usings, target framework, warnings-as-errors, analyzer level. Individual `.csproj` files inherit; do not duplicate these settings per project.
- **No `var` for primitive types in public APIs.** OK inside method bodies.
- **Async by default** for I/O. Method names end in `Async`. Return `Task` / `ValueTask`, accept `CancellationToken` as the last parameter.
- **No `Thread.Sleep`** in production code. Use `await Task.Delay(...)`.
- **DI registration** lives in `Program.cs` (Web/Worker) or a single `ServiceCollectionExtensions.cs` per project. Don't sprinkle `AddSingleton` calls across the codebase.
- **Logging** via `ILogger<T>`. Never `Console.WriteLine` outside `Program.cs`.
- **Secrets** via User Secrets in dev, environment variables / Key Vault in prod. Never commit `appsettings.Development.json` with real values.

## Out of scope for the agent

Do **not** modify:

- `<<EDIT ME: paths like infra/, db/migrations/, terraform/>>`
- `Directory.Build.props` / `global.json` / `.editorconfig` — unless the ticket is explicitly about tooling
- `*.csproj` package versions — bumping deps is its own ticket
- `.github/workflows/` unless the ticket is about CI

## How the agent should work in this repo

1. **Read the Jira ticket** before planning. Reference its key in commit messages and PR titles.
2. **Plan-mode first** for anything that touches more than one project or more than ~50 lines.
3. **TDD when feasible:** write the test in `tests/<Project>.Tests`, watch it fail, then implement.
4. **Run `dotnet format && dotnet build && dotnet test` before committing.** The pre-commit hook enforces this.
5. **Commit message style:** Conventional Commits — `feat(orders): add idempotency key (PROJ-123)`.
6. **PR draft → ready-for-review** after CI is green and review subagents agree.

## What the commit-time guard runs

```
dotnet format --verify-no-changes  →  dotnet build  →  dotnet test
```

If any step fails, commit is blocked. The hook is in `.claude/hooks/guard-commit.ps1`.

## Notes

- This repo uses a `Directory.Build.props` at root — see [`Directory.Build.props.example`](Directory.Build.props.example) for the recommended baseline.
- `.editorconfig` drives both formatting and analyzer severity. Don't bypass it with `#pragma warning disable` in production code unless you also add a comment explaining why and link to a follow-up ticket.
