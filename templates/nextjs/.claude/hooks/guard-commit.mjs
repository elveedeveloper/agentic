#!/usr/bin/env node
// Pre-Bash hook for Next.js: on `git commit`, run the full check including `next build`.

import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const payload = JSON.parse(readFileSync(0, 'utf8') || '{}');
const cmd = payload?.tool_input?.command ?? '';

if (!/\bgit\s+commit\b/.test(cmd)) {
  process.exit(0);
}

try {
  execSync('pnpm check', { stdio: 'inherit' });
  process.exit(0);
} catch {
  console.error('\n[guard-commit] pnpm check failed — commit blocked. Fix and retry.');
  process.exit(2);
}
