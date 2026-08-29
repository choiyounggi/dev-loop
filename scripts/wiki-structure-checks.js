#!/usr/bin/env node
// wiki-structure-checks — mechanical duplicate + format gate for the bundled wiki.
//
// The countable half of wiki-lint (checks 1, 3, 4 and the frontmatter/routing
// invariants AGENTS.md declares), enforced as code so CI catches drift before a
// human review does; the semantic half (trigger wording accuracy, vague
// qualifiers, staleness judgment) stays with the wiki-lint skill. Same split as
// scripts/wiki-lint-prohibitions.js (check 2) and test-floor.sh.
//
// usage: node scripts/wiki-structure-checks.js <wiki-root>
//
// exit 0  clean   — stdout one summary line `pages: N, indexes: M, findings: 0`
// exit 3  findings — same summary on stdout, one finding per line on stderr:
//                    `<check>:<file>: <detail>`
// exit 4  usage / unreadable root — reason on stderr, nothing on stdout
//
// Checks (all error-level; the live corpus is 100% compliant on every one,
// measured 2026-08-18 over 242 pages / 13 indexes):
//   no-frontmatter     page has no leading `---` frontmatter block
//   missing-key        frontmatter lacks a required key
//                      (id, domain, category, applies_to, confidence, sources,
//                       last_verified, related)
//   duplicate-id       two pages share one `id`
//   id-path-mismatch   `id` != path components joined with `-` (AGENTS.md:
//                      "Page ids: <domain>-<category>-<slug> matching the file
//                      path"; nested subtrees include every segment)
//   domain-mismatch    `domain` != first path component
//   category-mismatch  `category` != the path between domain and file (either
//                      the full sub-path or its last segment — both live forms)
//   bad-confidence     `confidence` not one of verified|field-tested|unverified
//   verified-no-sources `confidence: verified` with an empty `sources:` list
//   broken-index-link  index table row links to a file that does not exist
//   duplicate-index-row one index lists the same target twice
//   cross-domain-listing a domain index lists a page outside its own domain
//                      (routing scopes are disjoint — PR #93)
//   orphan-page        page listed in no index at all
//   bad-related        `related:` names an id no page carries
//   duplicate-frontmatter-key  a top-level frontmatter key appears more than
//                      once in the block (YAML last-key-wins silently drops
//                      the earlier occurrence)
//   stray-frontmatter-value  a key's value block has 2+ top-level `[...]`
//                      bracket literals, or a non-empty inline value followed
//                      by an indented `- ` bullet that belongs to no key
'use strict';

const fs = require('fs');
const path = require('path');

const REQUIRED_KEYS = ['id', 'domain', 'category', 'applies_to', 'confidence',
  'sources', 'last_verified', 'related'];
const CONFIDENCE = new Set(['verified', 'field-tested', 'unverified']);

const root = process.argv[2];
if (!root) { process.stderr.write('usage: wiki-structure-checks.js <wiki-root>\n'); process.exit(4); }
let rootStat;
try { rootStat = fs.statSync(root); } catch { rootStat = null; }
if (!rootStat || !rootStat.isDirectory()) {
  process.stderr.write(`wiki-structure-checks: '${root}' is not a readable directory\n`);
  process.exit(4);
}

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p, out);
    else if (entry.name.endsWith('.md')) out.push(p);
  }
  return out;
}

const all = walk(root);
const pages = all.filter((p) => path.basename(p) !== 'index.md');
const indexes = all.filter((p) => path.basename(p) === 'index.md');
const findings = [];
const report = (check, file, detail) => findings.push(`${check}:${file}: ${detail}`);

// --- per-page frontmatter checks -------------------------------------------
const idOwners = new Map();   // id -> [files]
const pageMeta = new Map();   // file -> { fm } (frontmatter text)

for (const p of pages) {
  const text = fs.readFileSync(p, 'utf8');
  const m = text.match(/^---\n([\s\S]*?)\n---/);
  if (!m) { report('no-frontmatter', p, 'page has no leading frontmatter block'); continue; }
  const fm = m[1];
  pageMeta.set(p, fm);
  const get = (k) => {
    const r = fm.match(new RegExp(`^${k}:\\s*(.*)$`, 'm'));
    return r ? r[1].trim() : null;
  };

  for (const k of REQUIRED_KEYS) {
    if (!new RegExp(`^${k}:`, 'm').test(fm)) report('missing-key', p, `frontmatter lacks '${k}'`);
  }

  const rel = path.relative(root, p).replace(/\.md$/, '');
  const parts = rel.split(path.sep);
  const id = get('id');
  if (id !== null) {
    const expected = parts.join('-');
    if (id !== expected) report('id-path-mismatch', p, `id '${id}' != path-derived '${expected}'`);
    if (!idOwners.has(id)) idOwners.set(id, []);
    idOwners.get(id).push(p);
  }
  const domain = get('domain');
  if (domain !== null && domain !== parts[0]) {
    report('domain-mismatch', p, `domain '${domain}' != path domain '${parts[0]}'`);
  }
  const category = get('category');
  if (category !== null && parts.length >= 2) {
    const subPath = parts.slice(1, -1).join('/');
    const lastSeg = parts[parts.length - 2];
    if (category !== subPath && category !== lastSeg) {
      report('category-mismatch', p, `category '${category}' != path category '${subPath}'`);
    }
  }
  const confidence = get('confidence');
  if (confidence !== null && !CONFIDENCE.has(confidence)) {
    report('bad-confidence', p, `confidence '${confidence}' not in verified|field-tested|unverified`);
  }
  if (confidence === 'verified') {
    // inline `sources: [x]` / `sources: x`, or a block list with >= 1 `- item`
    const inline = /^sources:\s*\S/m.test(fm) && !/^sources:\s*\[\s*\]\s*$/m.test(fm);
    const block = /^sources:\s*$/m.test(fm) &&
      new RegExp('^sources:\\s*\\n(\\s+-\\s+\\S)', 'm').test(fm);
    if (!inline && !block) report('verified-no-sources', p, 'confidence: verified with empty sources');
  }
}

for (const [id, owners] of idOwners) {
  if (owners.length > 1) report('duplicate-id', owners[1], `id '${id}' also used by ${owners[0]}`);
}

// --- frontmatter key hygiene -------------------------------------------------
for (const [p, fm] of pageMeta) {
  const lines = fm.split('\n');
  const keyLineIdx = [];
  for (let i = 0; i < lines.length; i++) {
    if (/^[A-Za-z_][A-Za-z0-9_-]*:/.test(lines[i])) keyLineIdx.push(i);
  }

  const keyCounts = new Map();
  for (const i of keyLineIdx) {
    const k = lines[i].match(/^([A-Za-z_][A-Za-z0-9_-]*):/)[1];
    keyCounts.set(k, (keyCounts.get(k) || 0) + 1);
  }
  for (const [k, count] of keyCounts) {
    if (count > 1) report('duplicate-frontmatter-key', p, `key '${k}' appears ${count} times`);
  }

  for (let ki = 0; ki < keyLineIdx.length; ki++) {
    const start = keyLineIdx[ki];
    const end = ki + 1 < keyLineIdx.length ? keyLineIdx[ki + 1] : lines.length;
    const [, key, rest] = lines[start].match(/^([A-Za-z_][A-Za-z0-9_-]*):(.*)$/);
    const inline = rest.trim();
    const body = lines.slice(start + 1, end);
    const bracketLines = body.filter((l) => /^\s+\[/.test(l));
    if (bracketLines.length >= 2) {
      report('stray-frontmatter-value', p, `key '${key}' has ${bracketLines.length} bracket-literal value lines`);
    } else if (inline !== '' && body.some((l) => /^\s+-\s/.test(l))) {
      report('stray-frontmatter-value', p, `key '${key}' has an inline value followed by a stray '- ' bullet`);
    }
  }
}

// --- index routing checks ---------------------------------------------------
const listed = new Set();

for (const ix of indexes) {
  const dir = path.dirname(ix);
  const text = fs.readFileSync(ix, 'utf8');
  const seen = new Set();
  // the domain an index routes for = its first path component under the root
  const ixDomain = path.relative(root, ix).split(path.sep)[0];
  for (const row of text.matchAll(/\|\s*\[([^\]]+)\]\(([^)]+)\)\s*\|/g)) {
    const target = row[2];
    if (/^https?:|^#/.test(target)) continue; // external links and in-page anchors are not file routes
    const resolved = path.normalize(path.join(dir, target));
    if (!fs.existsSync(resolved)) { report('broken-index-link', ix, `-> ${target}`); continue; }
    if (seen.has(resolved)) report('duplicate-index-row', ix, `lists ${target} twice`);
    seen.add(resolved);
    if (path.basename(resolved) === 'index.md') continue; // index-to-index cross-links are routing, not listing
    listed.add(resolved);
    const targetDomain = path.relative(root, resolved).split(path.sep)[0];
    if (targetDomain !== ixDomain) {
      report('cross-domain-listing', ix, `lists ${target} from domain '${targetDomain}'`);
    }
  }
}

for (const p of pages) {
  if (!listed.has(path.normalize(p))) report('orphan-page', p, 'listed in no index');
}

// --- related-id resolution --------------------------------------------------
const knownIds = new Set(idOwners.keys());
for (const [p, fm] of pageMeta) {
  const rm = fm.match(/^related:\s*\[([^\]]*)\]/m);
  if (!rm) continue;
  for (const r of rm[1].split(',').map((s) => s.trim()).filter(Boolean)) {
    if (!knownIds.has(r)) report('bad-related', p, `related id '${r}' resolves to no page`);
  }
}

// --- report -----------------------------------------------------------------
process.stdout.write(`pages: ${pages.length}, indexes: ${indexes.length}, findings: ${findings.length}\n`);
if (findings.length > 0) {
  for (const f of findings) process.stderr.write(f + '\n');
  process.exit(3);
}
process.exit(0);
