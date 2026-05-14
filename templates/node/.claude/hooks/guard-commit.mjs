#!/usr/bin/env node
// Pre-Bash hook: when the agent tries to `git commit`, run `npm run check` first.
// Block the commit if checks fail. Stdin is JSON describing the tool call.

import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const payload = JSON.parse(readFileSync(0, 'utf8') || '{}');
const cmd = payload?.tool_input?.command ?? '';

if (!/\bgit\s+commit\b/.test(cmd)) {
  process.exit(0); // not a commit; let it through
}

try {
  execSync('npm run check', { stdio: 'inherit' });
  process.exit(0);
} catch {
  console.error('\n[guard-commit] npm run check failed — commit blocked. Fix the errors and retry.');
  process.exit(2); // exit 2 = block the tool call
}
