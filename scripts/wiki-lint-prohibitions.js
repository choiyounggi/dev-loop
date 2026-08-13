#!/usr/bin/env node
// wiki-lint check 2 — mechanically enforceable prohibition-with-replacement rule.
//
// SCOPE     : page body only (no frontmatter), and NOT the `## Sources` section
//             (citation text quotes prohibitions and is not addressed to the reader).
// UNIT      : one directive item — a table cell, or a bullet/numbered item
//             (multi-sentence allowed; wrapped lines rejoined).
// DIRECTIVE : a clause in that unit that BEGINS with a prohibition token AND is
//             >= 3 words long (a 2-word cell like "Never read" is a state value
//             in a data column, not an instruction to the reader).
//             `never-fails` (hyphenated compound) is not a token.
// COMPLIANT : the unit is an `## Instead of` row, OR the unit carries at least one
//             other clause (>= 1 word) — the replacement action, or the mechanism
//             that makes the prohibition true.
// INFO      : a unit that is nothing but a bare 2-word prohibition clause (no other
//             content) — the declared blind spot (D5). Ambiguous by shape between a
//             state value (`Never read`) and a real directive (`Never retry`), so it
//             is reported for a human to look at, never as a checker error.
//
// Ported from the validated rule at .orchestration/evidence/i36-rule-probe.js — do
// not re-derive the parse; it was measured against the live corpus (61 directive
// units, 0 violations) before this script existed.
'use strict';

const fs = require('fs');
const path = require('path');

const TOKEN = "(?:don't|do not|never|avoid|must not)";
const STARTS = new RegExp(`^${TOKEN}(?![\\w-])`, 'i');
const ANY = new RegExp(`(?<![\\w-])${TOKEN}(?![\\w-])`, 'i');
const CLAUSE_SPLIT = /(?:\s+—\s+|;\s+|:\s+|(?<=[.!?])\s+)/;
const strip = (s) => s.replace(/[*`_]/g, '').trim();
const words = (s) => s.split(/\s+/).filter(Boolean).length;

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p, out);
    else if (entry.name.endsWith('.md')) out.push(p);
  }
  return out;
}

// Reassemble a page body into directive items: one per table cell, or per
// bullet/numbered item with its wrapped continuation lines rejoined.
function collectItems(body) {
  let section = '';
  let buf = [];
  const items = [];
  const flush = () => {
    if (buf.length) {
      items.push({ text: buf.join(' ').replace(/\s+/g, ' ').trim(), section });
      buf = [];
    }
  };

  for (const raw of body.split('\n')) {
    if (/^#{1,3}\s+/.test(raw)) {
      flush();
      section = raw.replace(/^#{1,3}\s+/, '').trim();
      continue;
    }
    if (raw.trim().startsWith('|')) {
      flush();
      if (/^\|[\s|:-]+\|$/.test(raw.trim())) continue; // table separator row
      raw
        .split('|')
        .slice(1, -1)
        .forEach((cell) => cell.trim() && items.push({ text: cell.trim(), section }));
      continue;
    }
    if (!raw.trim()) {
      flush();
      continue;
    }
    if (/^\s*(?:\d+\.|[-*])\s+/.test(raw)) {
      flush();
      buf.push(raw.replace(/^\s*(?:\d+\.|[-*])\s+/, ''));
    } else {
      buf.push(raw.trim());
    }
  }
  flush();
  return items;
}

function lint(files) {
  let directiveUnits = 0;
  let okInstead = 0;
  let okPair = 0;
  const violations = [];
  const infos = [];

  for (const file of files) {
    const raw = fs.readFileSync(file, 'utf8');
    const body = raw.replace(/^---\n[\s\S]*?\n---\n/, '');
    const items = collectItems(body);

    for (const { text, section } of items) {
      if (/^Sources$/i.test(section)) continue;
      const unit = strip(text);
      if (!ANY.test(unit)) continue;

      const clauses = unit
        .split(CLAUSE_SPLIT)
        .map((c) => c.trim())
        .filter(Boolean);
      const directives = clauses.filter((c) => STARTS.test(c) && words(c) >= 3);

      if (!directives.length) {
        // Known blind spot (D5): a unit that is nothing but a bare 2-word
        // prohibition clause is undecidable between a state value and a real
        // directive. Report it at info; never treat it as a violation.
        if (clauses.length === 1 && STARTS.test(clauses[0]) && words(clauses[0]) === 2) {
          infos.push(`${file}:${section}: ${unit}`);
        }
        continue;
      }

      directiveUnits++;
      if (/^Instead of$/i.test(section)) {
        okInstead++;
        continue;
      }
      if (clauses.some((c) => !directives.includes(c) && words(c) >= 1)) {
        okPair++;
        continue;
      }
      violations.push(`${file}:${section}: ${unit}`);
    }
  }

  return { directiveUnits, compliant: okInstead + okPair, violations, infos };
}

function main() {
  const target = process.argv[2] || 'wiki';

  let stat;
  try {
    stat = fs.statSync(target);
  } catch {
    stat = null;
  }
  if (!stat) {
    console.error(`wiki-lint-prohibitions: no such directory: ${target}`);
    process.exit(2);
  }
  const files = stat.isDirectory() ? walk(target) : [target];

  const { directiveUnits, compliant, violations, infos } = lint(files);

  if (violations.length) {
    console.log('--- violations ---');
    violations.forEach((v) => console.log(v));
  }
  if (infos.length) {
    console.log('--- info: bare 2-word prohibition cells (state value or directive — undecidable by shape) ---');
    infos.forEach((i) => console.log(i));
  }

  console.log('--- summary ---');
  console.log(`directives: ${directiveUnits}`);
  console.log(`compliant: ${compliant}`);
  console.log(`violations: ${violations.length}`);
  console.log(`info: ${infos.length}`);

  process.exit(violations.length ? 1 : 0);
}

main();
