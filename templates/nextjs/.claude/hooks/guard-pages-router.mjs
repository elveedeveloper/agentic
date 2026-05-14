#!/usr/bin/env node
// Block new files under `pages/` — this repo is App Router only.

import { readFileSync } from 'node:fs';
import { existsSync } from 'node:fs';

const payload = JSON.parse(readFileSync(0, 'utf8') || '{}');
const path = payload?.tool_input?.file_path ?? '';

if (!path) process.exit(0);

// Only block CREATING new pages-router files; editing pre-existing ones is allowed
// so a migration ticket can still touch them.
const isPagesRouter = /[/\\]pages[/\\]/.test(path);
const isNewFile = !existsSync(path);

if (isPagesRouter && isNewFile) {
  console.error(
    `[guard-pages-router] BLOCKED — new file under pages/: ${path}\n  This project is App Router only. Put new routes under src/app/ instead.`,
  );
  process.exit(2);
}
process.exit(0);
