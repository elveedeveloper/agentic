#!/usr/bin/env node
// Same secret-scan as Node template, plus NEXT_PUBLIC_ awareness:
// any secret-shaped value assigned to NEXT_PUBLIC_* is *also* blocked — those leak to the browser bundle.

import { readFileSync } from 'node:fs';

const payload = JSON.parse(readFileSync(0, 'utf8') || '{}');
const input = payload?.tool_input ?? {};
const content = [input.content, input.new_string, ...(input.edits ?? []).map((e) => e.new_string)]
  .filter(Boolean)
  .join('\n');

const PATTERNS = [
  { name: 'AWS access key', re: /AKIA[0-9A-Z]{16}/ },
  { name: 'GitHub PAT', re: /ghp_[A-Za-z0-9]{36}/ },
  { name: 'GitHub fine-grained PAT', re: /github_pat_[A-Za-z0-9_]{82}/ },
  { name: 'Stripe live key', re: /sk_live_[A-Za-z0-9]{24,}/ },
  { name: 'Private key block', re: /-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----/ },
  { name: 'Generic API key', re: /(api[_-]?key|secret|password)\s*[:=]\s*['"][A-Za-z0-9_\-]{20,}['"]/i },
  {
    name: 'Secret on NEXT_PUBLIC_ (would leak to browser!)',
    re: /NEXT_PUBLIC_[A-Z0-9_]*(SECRET|KEY|TOKEN|PASSWORD)/,
  },
];

const hits = PATTERNS.filter((p) => p.re.test(content));
if (hits.length > 0) {
  console.error(
    `[guard-secrets] BLOCKED:\n  - ${hits.map((h) => h.name).join('\n  - ')}\n  NEXT_PUBLIC_* values are bundled to the client — never put secrets there.`,
  );
  process.exit(2);
}
process.exit(0);
