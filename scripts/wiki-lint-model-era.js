#!/usr/bin/env node
// wiki-lint check 12 — model-era re-verification candidates (report-only).
//
// A model-coupled page (its body references model/LLM behavior) ages with model
// generations: guidance verified against one generation may be obsolete quirk
// workaround by the next. This script mechanically surfaces the candidates; the
// semantic judgment (re-verify, rewrite, or retire) stays with the wiki-lint
// skill. Same countable/semantic split as scripts/wiki-lint-prohibitions.js
// (check 2) and scripts/wiki-structure-checks.js (checks 1, 3, 4).
//
// COUPLED   : body matches a model-subject keyword (leading boundary excludes
//             hyphenated page-id mentions like backend-common-llm-*), scanned
//             OUTSIDE frontmatter, the `## Sources` section, and markdown link
//             URLs; `index.md` files are routing, never scanned.
// CANDIDATE : coupled AND (`verified_model` frontmatter absent, OR its value
//             contains no current-generation token as a substring).
// CURRENT   : --current <csv> beats DEV_LOOP_CURRENT_MODELS (csv) beats
//             DEFAULT_CURRENT. The default is deliberately overridable so the
//             checker's own list can age without editing callers.
//
// usage: node scripts/wiki-lint-model-era.js <wiki-root> [--current <csv>]
//
// exit 0  no candidates — stdout `pages: N, model-coupled: M, candidates: 0`
// exit 3  candidates    — same summary on stdout, one per line on stderr:
//                         `revalidate:<file>: <reason>`
// exit 4  usage / unreadable root — reason on stderr, nothing on stdout
//
// This is report-only by design: the live corpus legitimately carries
// candidates (~27 pages measured 2026-09-03), so it must NOT join the blocking
// wiki-checks step in .github/workflows/test.yml.
'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULT_CURRENT = ['opus-4', 'fable-5'];
const COUPLED = /(?<![A-Za-z0-9-])(claude|sonnet|opus|gpt-|llm|subagent|hallucinat|context window)/i;

function usage(msg) {
  process.stderr.write(`${msg}\nusage: wiki-lint-model-era.js <wiki-root> [--current <csv>]\n`);
  process.exit(4);
}

let root = null;
let currentArg = null;
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--current') {
    if (i + 1 >= argv.length) usage('--current requires a value');
    currentArg = argv[++i];
  } else if (argv[i].startsWith('--')) {
    usage(`unknown flag '${argv[i]}'`);
  } else if (root === null) {
    root = argv[i];
  } else {
    usage(`unexpected argument '${argv[i]}'`);
  }
}
if (!root) usage('missing <wiki-root>');
let rootStat;
try { rootStat = fs.statSync(root); } catch { rootStat = null; }
if (!rootStat || !rootStat.isDirectory()) usage(`'${root}' is not a readable directory`);

const fromCli = currentArg !== null;
const currentCsv = fromCli ? currentArg : (process.env.DEV_LOOP_CURRENT_MODELS || '');
const current = (fromCli || currentCsv ? currentCsv.split(',') : DEFAULT_CURRENT)
  .map((s) => s.trim().toLowerCase()).filter(Boolean);
if (current.length === 0) usage('current-model set is empty');

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p, out);
    else if (entry.name.endsWith('.md') && entry.name !== 'index.md') out.push(p);
  }
  return out;
}

const pages = walk(root);
let coupledCount = 0;
const candidates = [];

for (const p of pages) {
  const text = fs.readFileSync(p, 'utf8');
  const m = text.match(/^---\n([\s\S]*?)\n---/);
  const fm = m ? m[1] : '';
  let body = m ? text.slice(m[0].length) : text;
  // scan scope: drop the `## Sources` section (citation text is not guidance)
  // and markdown link URLs (a docs URL naming a model is not model coupling).
  body = body.replace(/^##\s+Sources\b[\s\S]*?(?=^## |(?![\s\S]))/m, '');
  body = body.replace(/\(https?:[^)]*\)/g, '()');

  if (!COUPLED.test(body)) continue;
  coupledCount++;

  const vm = fm.match(/^verified_model:\s*(.*)$/m);
  const value = vm ? vm[1].trim() : '';
  if (!value) {
    candidates.push(`revalidate:${p}: model-coupled, no verified_model`);
  } else if (!current.some((tok) => value.toLowerCase().includes(tok))) {
    candidates.push(`revalidate:${p}: verified_model '${value}' not in current set`);
  }
}

process.stdout.write(`pages: ${pages.length}, model-coupled: ${coupledCount}, candidates: ${candidates.length}\n`);
if (candidates.length > 0) {
  for (const c of candidates) process.stderr.write(c + '\n');
  process.exit(3);
}
process.exit(0);
