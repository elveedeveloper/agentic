# CI Babysitter — `/loop` on an open PR

When CI is slow or flaky, instead of refreshing the GitHub tab every 2 minutes, ask Claude to watch it for you and fix failures as they come. This is the cheapest, most useful piece of Tier-1 automation you can use today.

## The one-liner

After you push and the PR is open, in Claude Code:

```
/loop /check-pr PROJ-123
```

(`/loop` is dynamic-paced; Claude decides how often to wake up based on CI status. If you want a fixed cadence: `/loop 4m /check-pr PROJ-123`.)

## What "watching CI" actually means

There's no built-in `/check-pr` slash command — you build it from a prompt. Define it once and Claude runs the same routine each loop iteration.

**Suggested prompt** (paste this in your first message; the loop will repeat it):

```
Check the latest CI run for the PR matching ticket PROJ-123:

1. `gh pr view PROJ-123/* --json statusCheckRollup,number,headRefName`
2. If all checks pass: post a one-line comment on the PR ("CI green ✅"),
   update Jira to In Review, then stop the loop.
3. If any check is still running: report status briefly and let the loop continue.
4. If any check has failed:
   - Fetch the failing job log: `gh run view <id> --log-failed`
   - Identify the root cause (be brief — one paragraph)
   - Fix the code, commit, push to the PR branch
   - Let the loop continue to verify the next CI run

Hard limits:
- Stop after 3 fix attempts on the same failure
- Stop if you can't determine the cause from the log
- Stop if the failure looks like infrastructure (timeouts, runner crashes) rather than code
- Never force-push or amend commits
```

## Why dynamic pacing matters

`/loop` without an interval lets Claude self-pace. Internally:

- **CI still running, fresh push?** Wakes in ~4 min (likely still pending).
- **CI running for a while, halfway through expected time?** Wakes in ~2 min.
- **CI failed and Claude pushed a fix?** Wakes in ~4 min for the new run to start.

Fixed-interval (`/loop 30s`) burns context and money for no benefit. Use dynamic unless you know the exact cadence you need.

## When to use this vs. background agents

| Situation | Tool |
| --- | --- |
| You're at your desk, want to multitask while CI runs | `/loop /check-pr` — runs while Claude Code is open |
| You've shut your laptop, want CI fixes to happen overnight | `claude-pr-bot.yml` GitHub Action (Tier 2) |
| You want to react to specific human comments on the PR | `claude-pr-bot.yml` — reacts to `@claude` mentions |

`/loop` is **session-bound** — it stops when you close Claude Code. The GitHub Action is **always on**. Use both, for different needs.

## A common variant — "babysit until I'm back from lunch"

```
/loop 4m Check CI on PR #42. If it goes green, summarize the diff and stop. If it fails, post a comment with the root cause but DO NOT push a fix — I want to see the failure when I'm back.
```

Useful when you want awareness without automatic fixing.

## Things to know

- **The loop only runs while Claude Code is open.** Close the window, the loop dies. That's a feature, not a bug — you don't want background agent runs you forgot about racking up API spend.
- **Each iteration sees the full conversation context** (with cache hits for unchanged parts). Long conversations get expensive even when the loop is short — start fresh sessions for long-running watches.
- **Use the `gh` CLI exclusively** for GitHub interactions. The agent should not be hitting GitHub's web UI through any scraping mechanism.
- **Always give explicit "stop when" criteria.** Without them, the loop runs forever (until you kill it).
