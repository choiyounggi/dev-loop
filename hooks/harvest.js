#!/usr/bin/env node
/*
 * dev-loop insight harvester.
 *
 * Reads the Stop-hook payload on stdin, locates the session transcript, scans
 * the assistant's turns for "star Insight" blocks (the format the SessionStart
 * instruction asks the model to emit), de-duplicates by content hash, and
 * appends new insights to a per-session queue file under ~/.dev-loop/queue/.
 *
 * It never opens a PR and never edits the wiki — that is knowledge-flush's job.
 * Harvesting is cheap, offline, and non-blocking so a session end never waits on
 * network or git. This mirrors rtb-lore's gotcha-harvest split (Stop harvests to
 * a local queue; a separate on-demand step promotes + PRs).
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

// The delimiter line uses U+2500 (box drawings light horizontal); keep this in
// exact sync with the SessionStart instruction (hooks/insight-instruction.sh).
const BLOCK_RE = /★\s*Insight\s*─+\s*\n([\s\S]*?)\n\s*─+/g;

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch {
    return '';
  }
}

function safeJson(s) {
  try {
    return JSON.parse(s);
  } catch {
    return {};
  }
}

// Resolve the transcript path: prefer the Stop hook's transcript_path, else the
// newest .jsonl in the session's project dir under ~/.claude/projects/.
function resolveTranscript(payload) {
  const tp = payload.transcript_path;
  if (tp && fs.existsSync(tp)) return tp;

  const cwd = payload.cwd || process.cwd();
  const encoded = cwd.replace(/[/.]/g, '-');
  const projDir = path.join(os.homedir(), '.claude', 'projects', encoded);
  if (!fs.existsSync(projDir)) return null;
  const files = fs
    .readdirSync(projDir)
    .filter((f) => f.endsWith('.jsonl'))
    .map((f) => path.join(projDir, f))
    .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
  return files[0] || null;
}

// Pull the plain assistant text out of one transcript JSONL line.
function assistantTextFromLine(line) {
  const obj = safeJson(line);
  const msg = obj.message || obj;
  if (!msg || msg.role !== 'assistant') return '';
  const content = msg.content;
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content
      .filter((p) => p && p.type === 'text' && typeof p.text === 'string')
      .map((p) => p.text)
      .join('\n');
  }
  return '';
}

function parseBlock(body) {
  const fields = { trigger: '', directive: '', why: '', evidence: '', domain: '', tags: [] };
  const rest = [];
  for (const raw of body.split('\n')) {
    const m = raw.match(/^\s*(trigger|directive|why|evidence|domain|tags)\s*:\s*(.*)$/i);
    if (!m) {
      rest.push(raw);
      continue;
    }
    const key = m[1].toLowerCase();
    const val = m[2].trim();
    if (key === 'tags') {
      fields.tags = val
        .split(/[,\s]+/)
        .map((t) => t.trim().toLowerCase())
        .filter(Boolean)
        .slice(0, 4);
    } else {
      fields[key] = val;
    }
  }
  if (rest.join('').trim()) fields._extra = rest.join('\n').trim();
  return fields;
}

function contentHash(body) {
  const norm = body.replace(/\s+/g, ' ').trim().toLowerCase();
  return crypto.createHash('sha256').update(norm).digest('hex').slice(0, 16);
}

function main() {
  const payload = safeJson(readStdin());
  const cwd = payload.cwd || process.cwd();

  // Self-reflection guard: don't harvest the flush working checkout (recursion).
  const flushRepo = path.join(os.homedir(), '.dev-loop', 'repo');
  if (path.resolve(cwd).startsWith(path.resolve(flushRepo))) return;

  const transcript = resolveTranscript(payload);
  if (!transcript) return;

  let text;
  try {
    text = fs.readFileSync(transcript, 'utf8');
  } catch {
    return;
  }

  const assistant = text
    .split('\n')
    .filter(Boolean)
    .map(assistantTextFromLine)
    .filter(Boolean)
    .join('\n\n');

  const found = [];
  let m;
  while ((m = BLOCK_RE.exec(assistant)) !== null) {
    const body = m[1].trim();
    if (body.length < 30) continue; // too thin to be routable knowledge
    const fields = parseBlock(body);
    if (!fields.trigger || !fields.directive) continue; // must be routable + actionable
    // Drop the instruction's own example template if the model ever echoes it:
    // its trigger/directive still carry <...> placeholder brackets.
    if (/<[^>]+>/.test(fields.trigger) || /<[^>]+>/.test(fields.directive)) continue;
    found.push({ body, fields, hash: contentHash(body) });
  }
  const sessionId =
    payload.session_id ||
    path.basename(transcript, '.jsonl') ||
    String(Date.now());

  const queueDir = path.join(os.homedir(), '.dev-loop', 'queue');
  fs.mkdirSync(queueDir, { recursive: true });
  const queueFile = path.join(queueDir, `${sessionId}.jsonl`);

  const countRows = () => {
    if (!fs.existsSync(queueFile)) return 0;
    return fs.readFileSync(queueFile, 'utf8').split('\n').filter((l) => l.trim()).length;
  };
  // A flush empties the session file it drained; when this Stop has nothing to
  // add, remove the leftover so empty files stop accumulating in the queue dir.
  const cleanupIfEmpty = () => {
    if (fs.existsSync(queueFile) && countRows() === 0) fs.unlinkSync(queueFile);
  };

  if (!found.length) {
    cleanupIfEmpty();
    return;
  }

  // Seed the dedupe set from the session queue AND the processed store —
  // knowledge-flush empties the queue file when it retires rows, and the next
  // Stop re-parses the unchanged transcript, so without the second source every
  // flushed insight would be re-queued. Read-only: only the flush writes there.
  const processedFile = path.join(queueDir, '.processed.jsonl');
  const seen = new Set();
  for (const src of [queueFile, processedFile]) {
    if (!fs.existsSync(src)) continue;
    for (const line of fs.readFileSync(src, 'utf8').split('\n')) {
      const o = safeJson(line);
      if (o.hash) seen.add(o.hash);
    }
  }

  const repo = path.basename(cwd);
  const rows = [];
  for (const f of found) {
    if (seen.has(f.hash)) continue;
    seen.add(f.hash);
    rows.push(
      JSON.stringify({
        hash: f.hash,
        sessionId,
        repo,
        cwd,
        trigger: f.fields.trigger,
        directive: f.fields.directive,
        why: f.fields.why,
        evidence: f.fields.evidence,
        domain: f.fields.domain,
        tags: f.fields.tags,
        extra: f.fields._extra || '',
        content: f.body,
        harvestedAt: new Date().toISOString(),
        status: 'pending',
      })
    );
  }
  // Backstop cap, not policy: the SessionStart instruction asks for 0-3 insights
  // per session; 10 leaves room for legitimately rich sessions while stopping a
  // runaway session from queueing dozens (and burning a headless auto-flush run).
  const CAP = 10;
  const budget = Math.max(0, CAP - countRows());
  const toAppend = rows.slice(0, budget);
  if (toAppend.length) fs.appendFileSync(queueFile, toAppend.join('\n') + '\n');
  else cleanupIfEmpty();
}

try {
  main();
} catch {
  // Never let a harvest error surface to the user; it's a background nicety.
}
