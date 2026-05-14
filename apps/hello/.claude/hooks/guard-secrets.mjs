#!/usr/bin/env node
// Pre-Edit/Write/MultiEdit hook: scan the new content for common secret patterns.
// Block the write if any pattern matches.

import { readFileSync } from 'node:fs';

const payload = JSON.parse(readFileSync(0, 'utf8') || '{}');
const input = payload?.tool_input ?? {};
const content = [input.content, input.new_string, ...(input.edits ?? []).map((e) => e.new_string)]
  .filter(Boolean)
  .join('\n');

const PATTERNS = [
  { name: 'AWS access key', re: /AKIA[0-9A-Z]{16}/ },
  { name: 'AWS secret key', re: /aws_secret_access_key\s*=\s*['"]?[A-Za-z0-9/+=]{40}/i },
  { name: 'GitHub PAT', re: /ghp_[A-Za-z0-9]{36}/ },
  { name: 'GitHub fine-grained PAT', re: /github_pat_[A-Za-z0-9_]{82}/ },
  { name: 'Slack token', re: /xox[abprs]-[A-Za-z0-9-]{10,}/ },
  { name: 'Stripe live key', re: /sk_live_[A-Za-z0-9]{24,}/ },
  { name: 'Private key block', re: /-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----/ },
  {
    name: 'Generic API key assignment',
    re: /(api[_-]?key|secret|password)\s*=\s*['"][A-Za-z0-9_\-]{20,}['"]/i,
  },
];

const hits = PATTERNS.filter((p) => p.re.test(content));
if (hits.length > 0) {
  console.error(
    `[guard-secrets] BLOCKED — looks like a secret in the write:\n  - ${hits.map((h) => h.name).join('\n  - ')}\n  Move it to .env (gitignored) or a secret manager.`,
  );
  process.exit(2);
}
process.exit(0);
