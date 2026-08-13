#!/usr/bin/env node
/*
 * queue-claim.js — claim/release insight-queue rows by run id (issue #77).
 *
 * scripts/flush-lock.sh makes the two knowledge-flush entry points mutually
 * exclusive, but a lock alone is not proof against a stale actor (a paused or
 * TTL-expired holder can resume mid-work). This tool makes the QUEUE
 * self-defend: a run claims the rows it is about to ingest, so a second run —
 * racing past the lock, or reclaiming after a dead holder — sees those rows
 * as unavailable instead of re-ingesting them.
 *
 * Mutates each *.jsonl row IN PLACE (status "pending" -> "claimed", plus
 * claimedBy/claimedAt) rather than moving it to another file — this keeps the
 * row in hooks/harvest.js's dedupe seed (which reads the session queue file
 * AND .processed.jsonl), so a still-pending duplicate is never re-harvested.
 * .processed.jsonl (the retired store) is never touched by any subcommand.
 *
 * Row identity is hooks/harvest.js's own dedupe key, the "hash" field —
 * reused here rather than inventing a second id for the same row.
 *
 * usage:
 *   node queue-claim.js list             print claimable row ids, one per line
 *   node queue-claim.js claim [--max N]  claim up to N claimable rows, print their ids
 *   node queue-claim.js release <id>...  set specific claimed rows back to pending
 *
 * env overrides:
 *   DEV_LOOP_QUEUE_DIR      queue directory (default: ~/.dev-loop/queue)
 *   DEV_LOOP_FLUSH_RUN_ID   this run's id (default: <timestamp>-<pid>)
 *   DEV_LOOP_CLAIM_TTL      seconds before a claimed row is reclaimable (default: 3600)
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

function queueDir() {
  return process.env.DEV_LOOP_QUEUE_DIR || path.join(os.homedir(), '.dev-loop', 'queue');
}

function defaultRunId() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const ts =
    `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-` +
    `${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
  return `${ts}-${process.pid}`;
}

function runId() {
  return process.env.DEV_LOOP_FLUSH_RUN_ID || defaultRunId();
}

function claimTtlSec() {
  const v = parseInt(process.env.DEV_LOOP_CLAIM_TTL, 10);
  return Number.isFinite(v) ? v : 3600;
}

// Every *.jsonl in the queue dir except the retired store, sorted for a
// deterministic claim order.
function queueFiles() {
  const dir = queueDir();
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.jsonl') && f !== '.processed.jsonl')
    .sort()
    .map((f) => path.join(dir, f));
}

// Read one queue file into {raw, parsed} rows. `raw` is the exact original
// line — kept byte-for-byte for any row this run does not rewrite, so an
// unparseable line always survives untouched. `parsed` is null for a
// malformed line and for blank lines (which are dropped, matching
// harvest.js's own "non-blank line" convention).
function readRows(file) {
  const text = fs.readFileSync(file, 'utf8');
  const rows = [];
  for (const raw of text.split('\n')) {
    if (!raw.trim()) continue;
    let parsed = null;
    try {
      parsed = JSON.parse(raw);
    } catch {
      parsed = null;
    }
    rows.push({ raw, parsed });
  }
  return rows;
}

function writeRowsAtomic(file, rows) {
  const body = rows.map((r) => r.raw).join('\n') + '\n';
  const tmp = `${file}.tmp`;
  fs.writeFileSync(tmp, body);
  fs.renameSync(tmp, file);
}

function isClaimable(row, ttlSec, nowMs) {
  if (!row || !row.hash) return false;
  if (row.status === 'pending') return true;
  if (row.status === 'claimed') {
    const claimedMs = Date.parse(row.claimedAt);
    return nowMs - claimedMs > ttlSec * 1000;
  }
  return false;
}

function cmdList() {
  const nowMs = Date.now();
  const ttlSec = claimTtlSec();
  const ids = [];
  for (const file of queueFiles()) {
    for (const { parsed } of readRows(file)) {
      if (isClaimable(parsed, ttlSec, nowMs)) ids.push(parsed.hash);
    }
  }
  if (ids.length) process.stdout.write(ids.join('\n') + '\n');
}

function cmdClaim(argv) {
  let max = Infinity;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--max') {
      const n = parseInt(argv[i + 1], 10);
      if (Number.isFinite(n)) max = n;
      i++;
    }
  }

  const nowMs = Date.now();
  const ttlSec = claimTtlSec();
  const claimedAt = new Date(nowMs).toISOString();
  const who = runId();
  const claimedIds = [];
  let remaining = max;

  for (const file of queueFiles()) {
    const rows = readRows(file);
    let changed = false;
    for (const row of rows) {
      if (remaining <= 0) break;
      if (!isClaimable(row.parsed, ttlSec, nowMs)) continue;
      row.parsed.status = 'claimed';
      row.parsed.claimedBy = who;
      row.parsed.claimedAt = claimedAt;
      row.raw = JSON.stringify(row.parsed);
      changed = true;
      remaining -= 1;
      claimedIds.push(row.parsed.hash);
    }
    if (changed) writeRowsAtomic(file, rows);
  }

  if (claimedIds.length) process.stdout.write(claimedIds.join('\n') + '\n');
}

function cmdRelease(argv) {
  const ids = new Set(argv);
  if (!ids.size) return;

  for (const file of queueFiles()) {
    const rows = readRows(file);
    let changed = false;
    for (const row of rows) {
      if (!row.parsed || !row.parsed.hash || !ids.has(row.parsed.hash)) continue;
      row.parsed.status = 'pending';
      delete row.parsed.claimedBy;
      delete row.parsed.claimedAt;
      row.raw = JSON.stringify(row.parsed);
      changed = true;
    }
    if (changed) writeRowsAtomic(file, rows);
  }
}

function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  switch (cmd) {
    case 'list':
      cmdList();
      break;
    case 'claim':
      cmdClaim(rest);
      break;
    case 'release':
      cmdRelease(rest);
      break;
    default:
      process.stderr.write('usage: queue-claim.js list|claim [--max N]|release <id>...\n');
      process.exit(2);
  }
}

main();
