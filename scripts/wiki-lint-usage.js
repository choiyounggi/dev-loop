#!/usr/bin/env node
// wiki-lint check 18 — active pages with zero citations in the usage window (report-only).
//
// The usage file is fed by scripts/wiki-usage.sh (loop-implement step 7): one
// JSON object per applied page, {ts, page_id, row, task, source}. This script
// lists every ACTIVE page (frontmatter `status` absent or `active`, index.md
// never counted) whose frontmatter `id` has no record with ts >= cutoff. A
// zero-citation page is a review queue, never a retire verdict — recent and
// rare-case pages sit at zero legitimately — so this never fails a run.
//
// cutoff: the same UTC calendar day `months` months earlier, with the day of
// month CLAMPED to that month's length (2026-08-31 minus 6 months is
// 2026-02-28). a setUTCMonth-based subtraction is NOT used: it overflows on
// day 29-31 (2026-08-31 minus 6 would land on 2026-03-03).
//
// usage: node scripts/wiki-lint-usage.js <wiki-root> [--usage <jsonl>] [--months <n>] [--now <iso>]
//   --usage  default $PWD/.dev-loop/wiki-usage.jsonl
//   --months default 6 (non-negative integer)
//   --now    default the current time (an ISO-8601 instant; tests inject it)
//
// exit 0  always after a valid invocation — stdout:
//           `usage data: none` (only when the file is absent, empty or whitespace)
//           `pages: N, cited: C, uncited: U, skipped: S, unknown: K`
//         stderr, one per finding: `uncited:<file>: no citation since <YYYY-MM-DD>`
//         (no findings at all when there is no usage data)
// exit 4  usage — missing/unreadable root, unknown flag, non-integer months,
//         unparseable --now; reason on stderr, nothing on stdout
//
// Report-only by design: it must NOT join the blocking wiki-checks step in
// .github/workflows/test.yml (same rule as scripts/wiki-lint-model-era.js).
'use strict';

const fs = require('fs');
const path = require('path');

function usage(msg) {
  process.stderr.write(`${msg}\nusage: wiki-lint-usage.js <wiki-root> [--usage <jsonl>] [--months <n>] [--now <iso>]\n`);
  process.exit(4);
}

let root = null;
let usageFile = null;
let months = 6;
let nowArg = null;
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--usage') {
    if (i + 1 >= argv.length) usage('--usage requires a value');
    usageFile = argv[++i];
  } else if (a === '--months') {
    if (i + 1 >= argv.length) usage('--months requires a value');
    if (!/^\d+$/.test(argv[i + 1])) usage(`--months must be a non-negative integer, got '${argv[i + 1]}'`);
    months = Number(argv[++i]);
  } else if (a === '--now') {
    if (i + 1 >= argv.length) usage('--now requires a value');
    nowArg = argv[++i];
  } else if (a.startsWith('--')) {
    usage(`unknown flag '${a}'`);
  } else if (root === null) {
    root = a;
  } else {
    usage(`unexpected argument '${a}'`);
  }
}
if (!root) usage('missing <wiki-root>');
let rootStat;
try { rootStat = fs.statSync(root); } catch { rootStat = null; }
if (!rootStat || !rootStat.isDirectory()) usage(`'${root}' is not a readable directory`);
const now = nowArg === null ? new Date() : new Date(nowArg);
if (Number.isNaN(now.getTime())) usage(`--now is not an ISO-8601 instant: '${nowArg}'`);
if (usageFile === null) usageFile = path.join(process.cwd(), '.dev-loop', 'wiki-usage.jsonl');

function cutoffFor(at, n) {
  const y = at.getUTCFullYear();
  const m = at.getUTCMonth() - n;
  const daysInMonth = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
  return new Date(Date.UTC(y, m, Math.min(at.getUTCDate(), daysInMonth)));
}
const cutoff = cutoffFor(now, months);

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p, out);
    else if (entry.name.endsWith('.md') && entry.name !== 'index.md') out.push(p);
  }
  return out;
}

const pages = [];
for (const p of walk(root).sort()) {
  const text = fs.readFileSync(p, 'utf8');
  const m = text.match(/^---\n([\s\S]*?)\n---/);
  const fm = m ? m[1] : '';
  const sm = fm.match(/^status:\s*(.*)$/m);
  const status = sm ? sm[1].trim() : 'active';
  if (status !== 'active') continue;
  const im = fm.match(/^id:\s*(.*)$/m);
  pages.push({ file: p, id: im ? im[1].trim() : '' });
}

let raw = '';
try { raw = fs.readFileSync(usageFile, 'utf8'); } catch { raw = ''; }
const lines = raw.split('\n').filter((l) => l.trim() !== '');
const ids = new Set(pages.map((p) => p.id));
const cited = new Set();
let skipped = 0;
let unknown = 0;
if (lines.length === 0) {
  process.stdout.write('usage data: none\n');
} else {
  for (const l of lines) {
    let r;
    try { r = JSON.parse(l); } catch { skipped++; continue; }
    if (!r || typeof r.page_id !== 'string' || typeof r.ts !== 'string') { skipped++; continue; }
    const t = new Date(r.ts);
    if (Number.isNaN(t.getTime())) { skipped++; continue; }
    if (!ids.has(r.page_id)) { unknown++; continue; }
    if (t >= cutoff) cited.add(r.page_id);
  }
}
const uncited = lines.length === 0 ? [] : pages.filter((p) => !cited.has(p.id));
process.stdout.write(`pages: ${pages.length}, cited: ${cited.size}, uncited: ${uncited.length}, skipped: ${skipped}, unknown: ${unknown}\n`);
const since = cutoff.toISOString().slice(0, 10);
for (const p of uncited) process.stderr.write(`uncited:${p.file}: no citation since ${since}\n`);
process.exit(0);
