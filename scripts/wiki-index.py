#!/usr/bin/env python3
"""dev-loop — local vector index over the bundled wiki.

CLI contract (every path exits 0 unless stated):

    wiki-index.py --build          full rebuild      (3 = lock held, 4 = wiki root
                                   missing, 5 = embedding backend unavailable)
    wiki-index.py --incremental    changed pages only(same codes as --build)
    wiki-index.py --status         one stdout token: fresh | full | incremental | disabled
    wiki-index.py search --query T [--k 5] [--domain D] [--engine auto|scan|vec0] [--json]
    wiki-index.py page --page-id ID                  (1 = unknown page_id)
    wiki-index.py eval --cases FILE [--k 5]          (4 = no index)

Storage lives under DEV_LOOP_WIKI_INDEX_DIR (default ~/.dev-loop/wiki-index):
wiki.db, manifest.json, .build.lock/, build.log, models/. A relative override is
anchored to $HOME; a relative DEV_LOOP_WIKI_ROOT is anchored to the plugin root —
never to the working directory, which belongs to whatever launched the process.

Only the stdlib is imported at module level: `--status`, `search`, `page` and
test-hash builds must run under any python3 on PATH. fastembed and sqlite_vec
are imported inside the functions that need them, so a missing package degrades
that one path instead of breaking the module.
"""

import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import sqlite3
import struct
import sys
import time
from dataclasses import dataclass
from pathlib import Path

DEFAULT_MODEL = "BAAI/bge-small-en-v1.5"
HASH_DIM = 64
SNIPPET_CHARS = 240
DEFAULT_LOCK_TTL = 1800
MAX_K = 50

TRIGGER_SECTION = "When this applies"
DO_THIS_SECTION = "Do this"
EDGE_CASES_SECTION = "Edge cases"
INSTEAD_OF_SECTION = "Instead of"

_FRONTMATTER_FIELD = re.compile(
    r"^(id|domain|category|confidence|last_verified|status):\s*(.*)$"
)
_INDEX_ROW = re.compile(r"^\| \[[^\]]+\]\(([^)]+)\) \| (.+) \|$")
_NUMBERED_ITEM = re.compile(r"^\s*\d+\.\s+")

DDL = (
    "CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT)",
    "CREATE TABLE IF NOT EXISTS pages("
    "path TEXT PRIMARY KEY, page_id TEXT NOT NULL, sha256 TEXT NOT NULL)",
    "CREATE TABLE IF NOT EXISTS chunks("
    "id INTEGER PRIMARY KEY, page_id TEXT NOT NULL, path TEXT NOT NULL, "
    "domain TEXT, category TEXT, confidence TEXT, last_verified TEXT, "
    "section TEXT NOT NULL, ordinal INTEGER NOT NULL, text TEXT NOT NULL, "
    "snippet TEXT NOT NULL, embedding BLOB NOT NULL)",
    "CREATE INDEX IF NOT EXISTS chunks_path ON chunks(path)",
)


# --------------------------------------------------------------------------
# configuration
# --------------------------------------------------------------------------


def _env(name):
    """An empty value counts as unset — an exported-but-blank var is not a choice."""
    return os.environ.get(name) or None


def _anchored(raw, default, root):
    """Resolve a path-valued setting against a code-derived root, never the CWD.

    These entry points are started by something that owns the working directory
    (the SessionStart hook, a nohup'd rebuild, the MCP server the harness
    spawns), so the same relative value would otherwise mean a different
    directory per launcher. `~` expands first, so an operator's `~/x` counts as
    absolute.
    """
    path = Path(raw if raw else default).expanduser()
    return path if path.is_absolute() else Path(root) / path


@dataclass
class Config:
    index_dir: Path
    wiki_root: Path
    model_name: str
    plugin_version: str
    lock_ttl: int
    run_id: str
    enabled: bool

    @classmethod
    def from_env(cls):
        scripts_dir = Path(__file__).resolve().parent
        index_dir = _anchored(
            _env("DEV_LOOP_WIKI_INDEX_DIR"), "~/.dev-loop/wiki-index", Path.home()
        )
        wiki_root = _anchored(
            _env("DEV_LOOP_WIKI_ROOT"), scripts_dir.parent / "wiki", scripts_dir.parent
        )
        try:
            ttl = int(_env("DEV_LOOP_WIKI_LOCK_TTL") or DEFAULT_LOCK_TTL)
        except ValueError:
            ttl = DEFAULT_LOCK_TTL
        run_id = _env("DEV_LOOP_WIKI_RUN_ID") or "%s-%d" % (
            time.strftime("%Y%m%d-%H%M%S"),
            os.getpid(),
        )
        return cls(
            index_dir=index_dir,
            wiki_root=wiki_root,
            model_name=_env("DEV_LOOP_WIKI_EMBED_MODEL") or DEFAULT_MODEL,
            plugin_version=_plugin_version(scripts_dir.parent),
            lock_ttl=ttl,
            run_id=run_id,
            enabled=(_env("DEV_LOOP_WIKI_INDEX") or "1").lower()
            not in ("0", "off", "false"),
        )


def _plugin_version(plugin_root):
    try:
        with open(plugin_root / ".claude-plugin" / "plugin.json", encoding="utf-8") as fh:
            return str(json.load(fh)["version"])
    except (OSError, ValueError, KeyError, TypeError):
        return "unknown"


# --------------------------------------------------------------------------
# page parsing and chunking
# --------------------------------------------------------------------------


def _collapse(text):
    return re.sub(r"\s+", " ", text).strip()


def _split_sections(body):
    """Map each exact `## <name>` heading to its body, up to the next `## `."""
    sections = {}
    name = None
    buf = []
    for line in body.splitlines():
        if line.startswith("## "):
            if name is not None:
                sections[name] = "\n".join(buf)
            name = line[3:].strip()
            buf = []
        elif name is not None:
            buf.append(line)
    if name is not None:
        sections[name] = "\n".join(buf)
    return sections


def parse_page(path, wiki_root):
    """Parse one wiki page; return None (and report on stderr) when unusable."""
    relpath = path.relative_to(wiki_root).as_posix()
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print("skip %s: unreadable (%s)" % (relpath, exc), file=sys.stderr)
        return None

    if not text.startswith("---\n"):
        print("skip %s: no frontmatter" % relpath, file=sys.stderr)
        return None
    end = text.find("\n---\n", 3)
    if end == -1:
        print("skip %s: unterminated frontmatter" % relpath, file=sys.stderr)
        return None

    fields = {}
    for line in text[4:end].splitlines():
        match = _FRONTMATTER_FIELD.match(line)
        if match:
            fields[match.group(1)] = match.group(2).strip().strip("'\"")

    if not fields.get("id") or not fields.get("domain"):
        print("skip %s: missing id or domain" % relpath, file=sys.stderr)
        return None

    body = text[end + len("\n---\n") :]
    return {
        "page_id": fields["id"],
        "path": relpath,
        "domain": fields["domain"],
        "category": fields.get("category", ""),
        "confidence": fields.get("confidence", ""),
        "last_verified": fields.get("last_verified", ""),
        "body": body,
        "sections": _split_sections(body),
    }


def load_when_map(wiki_root):
    """Map each page path to its domain index's "load when" cell.

    That sentence is the hand-curated routing key; the trigger chunk has to
    carry it or vector search is reproducing a weaker signal than the index
    already has.
    """
    mapping = {}
    for pattern in ("*/index.md", "*/*/index.md"):
        for index_file in sorted(wiki_root.glob(pattern)):
            try:
                lines = index_file.read_text(encoding="utf-8").splitlines()
            except (OSError, UnicodeDecodeError):
                continue
            for line in lines:
                match = _INDEX_ROW.match(line)
                if not match:
                    continue
                target = (index_file.parent / match.group(1)).resolve()
                try:
                    key = target.relative_to(wiki_root.resolve()).as_posix()
                except ValueError:
                    continue
                # First index wins: a page belongs to the index that lists it
                # closest to itself, and later files must not overwrite that.
                mapping.setdefault(key, match.group(2).strip())
    return mapping


def _table_rows(section_text):
    """Data rows of a markdown table, as `cell — cell` strings."""
    rows = []
    for line in section_text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if not cells:
            continue
        if all(c and set(c) <= set("-: ") for c in cells):
            continue  # the |---|---| separator
        rows.append(cells)
    return [" — ".join(cells) for cells in rows[1:]]  # rows[0] is the header


def _numbered_items(section_text):
    """Numbered items with their continuation lines, in order."""
    items = []
    current = None
    lines = section_text.splitlines()
    for i, line in enumerate(lines):
        if _NUMBERED_ITEM.match(line):
            if current is not None:
                items.append("\n".join(current))
            current = [line]
            continue
        if current is None:
            continue
        if line.strip().startswith("|"):
            items.append("\n".join(current))
            current = None
            continue
        if not line.strip():
            nxt = lines[i + 1] if i + 1 < len(lines) else ""
            if nxt and not nxt.startswith((" ", "\t")) and not _NUMBERED_ITEM.match(nxt):
                items.append("\n".join(current))
                current = None
            else:
                current.append(line)
            continue
        current.append(line)
    if current is not None:
        items.append("\n".join(current))
    return items


def chunk_page(doc, load_when):
    """Section-level chunks: one page becomes trigger/directive/edge_case/instead_of.

    Embedding a whole ~888-word page blurs several topics into one vector; the
    page contract already marks the boundaries, so they are the chunk edges.
    """
    sections = doc["sections"]
    chunks = []

    def add(section, ordinal, text):
        collapsed = _collapse(text)
        if collapsed:
            chunks.append(
                {"section": section, "ordinal": ordinal, "text": collapsed,
                 "snippet": collapsed[:SNIPPET_CHARS]}
            )

    trigger = sections.get(TRIGGER_SECTION, "").strip()
    if load_when:
        trigger = (trigger + "\nLoad when: " + load_when).strip()
    add("trigger", 0, trigger)

    for ordinal, item in enumerate(_numbered_items(sections.get(DO_THIS_SECTION, ""))):
        add("directive", ordinal, item)
    offset = len([c for c in chunks if c["section"] == "directive"])
    for ordinal, row in enumerate(_table_rows(sections.get(DO_THIS_SECTION, ""))):
        add("directive", offset + ordinal, row)

    for ordinal, row in enumerate(_table_rows(sections.get(EDGE_CASES_SECTION, ""))):
        add("edge_case", ordinal, row)
    for ordinal, row in enumerate(_table_rows(sections.get(INSTEAD_OF_SECTION, ""))):
        add("instead_of", ordinal, row)

    return chunks


# --------------------------------------------------------------------------
# embedding
# --------------------------------------------------------------------------


def _l2_normalise(vec):
    norm = sum(v * v for v in vec) ** 0.5
    if norm <= 0:
        return vec
    return [v / norm for v in vec]


class HashEmbedder:
    """Deterministic signed hashed bag-of-words — the offline test backend.

    Keeps bats free of the 133MB model download; the scan-vs-vec0 contract test
    is what stops this fake from drifting away from the real ranking path.
    """

    name = "test-hash"
    dim = HASH_DIM

    def embed(self, texts):
        out = []
        for text in texts:
            vec = [0.0] * HASH_DIM
            for token in re.findall(r"[a-z0-9]+", text.lower()):
                digest = int(hashlib.sha1(token.encode("utf-8")).hexdigest()[:8], 16)
                vec[digest % HASH_DIM] += 1.0 if (digest >> 31) & 1 == 0 else -1.0
            out.append(_l2_normalise(vec))
        return out


class FastembedEmbedder:
    """ONNX CPU embeddings, cached under the index dir (no global installs)."""

    def __init__(self, model_name, cache_dir):
        from fastembed import TextEmbedding  # noqa: PLC0415 — optional dependency

        self.model = TextEmbedding(model_name=model_name, cache_dir=str(cache_dir))
        self.name = model_name
        self.dim = next(
            m["dim"]
            for m in TextEmbedding.list_supported_models()
            if m["model"] == model_name
        )

    def embed(self, texts):
        return [_l2_normalise([float(x) for x in vec]) for vec in self.model.embed(texts)]


def make_embedder(model_name, cache_dir):
    if model_name == "test-hash":
        return HashEmbedder()
    return FastembedEmbedder(model_name, cache_dir)


def pack(vec):
    return struct.pack("<%df" % len(vec), *vec)


def unpack(blob):
    return list(struct.unpack("<%df" % (len(blob) // 4), blob))


# --------------------------------------------------------------------------
# filesystem helpers
# --------------------------------------------------------------------------


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(65536), b""):
            digest.update(block)
    return digest.hexdigest()


def list_pages(wiki_root):
    return sorted(
        p.relative_to(wiki_root).as_posix()
        for p in wiki_root.rglob("*.md")
        if p.name != "index.md" and p.is_file()
    )


def current_pages(cfg):
    return {rel: sha256_file(cfg.wiki_root / rel) for rel in list_pages(cfg.wiki_root)}


def _utc_now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def write_manifest(cfg, embedder_name, dim, pages):
    """Written last, via tmp + replace: the manifest is the index's commit point."""
    manifest = {
        "plugin_version": cfg.plugin_version,
        "model": embedder_name,
        "dim": dim,
        "built_at": _utc_now(),
        "pages": pages,
    }
    tmp = cfg.index_dir / "manifest.json.tmp"
    tmp.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(tmp, cfg.index_dir / "manifest.json")
    return manifest


def read_manifest(index_dir):
    try:
        with open(Path(index_dir) / "manifest.json", encoding="utf-8") as fh:
            manifest = json.load(fh)
    except (OSError, ValueError):
        return None
    if not isinstance(manifest, dict):
        return None
    required = ("plugin_version", "model", "dim", "built_at", "pages")
    if any(key not in manifest for key in required):
        return None
    if not isinstance(manifest["pages"], dict):
        return None
    return manifest


# --------------------------------------------------------------------------
# lock (owner token + TTL, per scripts/flush-lock.sh's semantics)
# --------------------------------------------------------------------------


def _pid_alive(pid):
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    except (TypeError, ValueError):
        return False
    return True


def _read_owner(lock_dir):
    try:
        parts = (lock_dir / "owner").read_text(encoding="utf-8").split()
    except OSError:
        return None
    if len(parts) != 3:
        return None
    try:
        return parts[0], int(parts[1]), int(parts[2])
    except ValueError:
        return None


def _claim(lock_dir, run_id):
    (lock_dir / "owner").write_text(
        "%s %d %d\n" % (run_id, os.getpid(), int(time.time())), encoding="utf-8"
    )


def acquire_lock(index_dir, run_id, ttl):
    lock_dir = Path(index_dir) / ".build.lock"
    try:
        os.mkdir(lock_dir)
    except FileExistsError:
        pass
    else:
        _claim(lock_dir, run_id)
        return True

    owner = _read_owner(lock_dir)
    if owner is not None and owner[0] == run_id:
        _claim(lock_dir, run_id)  # re-entrant: this run already owns the build
        return True

    if owner is not None:
        age = int(time.time()) - owner[2]
        # A live holder keeps the lock past the TTL; a dead pid alone does not
        # make it stale, because the owner may be a detached wrapper.
        if age <= ttl or _pid_alive(owner[1]):
            print("held %s %ds" % (owner[0], age), file=sys.stderr)
            return False

    try:
        shutil.rmtree(lock_dir)
        os.mkdir(lock_dir)
    except (OSError, FileExistsError):
        print("held %s" % (owner[0] if owner else "unknown"), file=sys.stderr)
        return False
    _claim(lock_dir, run_id)
    return True


def release_lock(index_dir, run_id):
    lock_dir = Path(index_dir) / ".build.lock"
    owner = _read_owner(lock_dir)
    if owner is None or owner[0] == run_id:
        shutil.rmtree(lock_dir, ignore_errors=True)


# --------------------------------------------------------------------------
# sqlite helpers
# --------------------------------------------------------------------------


def _open_writer(path):
    conn = sqlite3.connect(str(path))
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


def open_ro(cfg):
    path = cfg.index_dir / "wiki.db"
    if not path.is_file():
        return None
    try:
        conn = sqlite3.connect("file:%s?mode=ro" % path, uri=True)
    except sqlite3.Error:
        return None
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


def try_load_vec(conn):
    try:
        import sqlite_vec  # noqa: PLC0415 — optional dependency
    except ImportError:
        return False
    try:
        conn.enable_load_extension(True)
        sqlite_vec.load(conn)
        conn.enable_load_extension(False)
    except (AttributeError, sqlite3.Error):
        return False
    return True


def _meta(conn, key, default=None):
    try:
        row = conn.execute("SELECT value FROM meta WHERE key = ?", (key,)).fetchone()
    except sqlite3.Error:
        return default
    return row[0] if row else default


def _insert_page(conn, doc, sha, chunks, vectors, vec0):
    conn.execute(
        "INSERT OR REPLACE INTO pages(path, page_id, sha256) VALUES (?, ?, ?)",
        (doc["path"], doc["page_id"], sha),
    )
    for chunk, vector in zip(chunks, vectors):
        cursor = conn.execute(
            "INSERT INTO chunks(page_id, path, domain, category, confidence, "
            "last_verified, section, ordinal, text, snippet, embedding) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                doc["page_id"], doc["path"], doc["domain"], doc["category"],
                doc["confidence"], doc["last_verified"], chunk["section"],
                chunk["ordinal"], chunk["text"], chunk["snippet"], pack(vector),
            ),
        )
        if vec0:
            conn.execute(
                "INSERT INTO chunk_vec(rowid, embedding) VALUES (?, ?)",
                (cursor.lastrowid, pack(vector)),
            )


def _index_pages(conn, cfg, embedder, relpaths, load_when, vec0):
    """Parse, chunk, embed and insert each page; return {relpath: sha256}.

    A page that cannot be parsed still gets its sha recorded. The manifest is
    the cache key of the whole wiki directory, so leaving a skipped page out of
    it would make `--status` report a difference on every run and the
    SessionStart hook reindex forever over one malformed file.
    """
    indexed = {}
    for rel in relpaths:
        path = cfg.wiki_root / rel
        try:
            sha = sha256_file(path)
        except OSError:
            continue  # removed between listing and hashing
        indexed[rel] = sha
        doc = parse_page(path, cfg.wiki_root)
        if doc is None:
            continue
        chunks = chunk_page(doc, load_when.get(rel, ""))
        vectors = embedder.embed([c["text"] for c in chunks]) if chunks else []
        _insert_page(conn, doc, sha, chunks, vectors, vec0)
    return indexed


# --------------------------------------------------------------------------
# build / incremental / status
# --------------------------------------------------------------------------


def build(cfg):
    if not cfg.wiki_root.is_dir():
        print("wiki root missing: %s" % cfg.wiki_root, file=sys.stderr)
        return 4
    cfg.index_dir.mkdir(parents=True, exist_ok=True)
    if not acquire_lock(cfg.index_dir, cfg.run_id, cfg.lock_ttl):
        return 3
    try:
        tmp = cfg.index_dir / "wiki.db.tmp"
        for stray in (tmp, Path(str(tmp) + "-wal"), Path(str(tmp) + "-shm")):
            if stray.exists():
                stray.unlink()

        try:
            embedder = make_embedder(cfg.model_name, cfg.index_dir / "models")
        except Exception as exc:  # noqa: BLE001 — any backend failure is exit 5
            print("embedding backend unavailable: %s" % exc, file=sys.stderr)
            return 5
        load_when = load_when_map(cfg.wiki_root)
        conn = _open_writer(tmp)
        try:
            for statement in DDL:
                conn.execute(statement)
            vec0 = try_load_vec(conn)
            if vec0:
                conn.execute(
                    "CREATE VIRTUAL TABLE chunk_vec USING "
                    "vec0(embedding float[%d] distance_metric=cosine)" % embedder.dim
                )
            pages = _index_pages(
                conn, cfg, embedder, list_pages(cfg.wiki_root), load_when, vec0
            )
            for key, value in (
                ("model", embedder.name), ("dim", str(embedder.dim)),
                ("vec0", "1" if vec0 else "0"),
                ("plugin_version", cfg.plugin_version), ("built_at", _utc_now()),
            ):
                conn.execute(
                    "INSERT OR REPLACE INTO meta(key, value) VALUES (?, ?)", (key, value)
                )
            conn.commit()
            conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        finally:
            conn.close()

        # The database is only discoverable under its final name once complete,
        # and the manifest — the thing every reader trusts — lands after it.
        os.replace(tmp, cfg.index_dir / "wiki.db")
        for stray in (Path(str(tmp) + "-wal"), Path(str(tmp) + "-shm")):
            if stray.exists():
                stray.unlink()
        write_manifest(cfg, embedder.name, embedder.dim, pages)
        return 0
    finally:
        release_lock(cfg.index_dir, cfg.run_id)


def incremental(cfg):
    if not cfg.wiki_root.is_dir():
        print("wiki root missing: %s" % cfg.wiki_root, file=sys.stderr)
        return 4
    manifest = read_manifest(cfg.index_dir)
    if manifest is None or not (cfg.index_dir / "wiki.db").is_file() or status(cfg) == "full":
        return build(cfg)

    if not acquire_lock(cfg.index_dir, cfg.run_id, cfg.lock_ttl):
        return 3
    try:
        old = manifest["pages"]
        new = current_pages(cfg)
        removed = [p for p in old if p not in new]
        changed = [p for p in sorted(new) if old.get(p) != new[p]]

        try:
            embedder = make_embedder(cfg.model_name, cfg.index_dir / "models")
        except Exception as exc:  # noqa: BLE001 — any backend failure is exit 5
            print("embedding backend unavailable: %s" % exc, file=sys.stderr)
            return 5
        load_when = load_when_map(cfg.wiki_root)
        conn = _open_writer(cfg.index_dir / "wiki.db")
        try:
            vec0 = _meta(conn, "vec0") == "1" and try_load_vec(conn)
            conn.execute("BEGIN")
            stale = removed + changed
            for rel in stale:
                conn.execute("DELETE FROM chunks WHERE path = ?", (rel,))
                conn.execute("DELETE FROM pages WHERE path = ?", (rel,))
            if vec0 and stale:
                conn.execute(
                    "DELETE FROM chunk_vec WHERE rowid NOT IN (SELECT id FROM chunks)"
                )
            indexed = _index_pages(conn, cfg, embedder, changed, load_when, vec0)
            conn.execute(
                "INSERT OR REPLACE INTO meta(key, value) VALUES ('built_at', ?)",
                (_utc_now(),),
            )
            conn.commit()
            conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        except sqlite3.Error:
            conn.rollback()
            raise
        finally:
            conn.close()

        pages = {p: sha for p, sha in old.items() if p not in removed and p not in changed}
        pages.update(indexed)
        write_manifest(cfg, manifest["model"], manifest["dim"], pages)
        return 0
    finally:
        release_lock(cfg.index_dir, cfg.run_id)


def status(cfg):
    """One token. The manifest is the cache key of a derived index: it carries
    every input that changes the result (plugin version, model, per-page sha)."""
    if not cfg.enabled or not cfg.wiki_root.is_dir():
        return "disabled"
    manifest = read_manifest(cfg.index_dir)
    if manifest is None:
        return "full"
    if manifest["plugin_version"] != cfg.plugin_version:
        return "full"
    if manifest["model"] != cfg.model_name:
        return "full"
    if not (cfg.index_dir / "wiki.db").is_file():
        return "full"
    if manifest["pages"] != current_pages(cfg):
        return "incremental"
    return "fresh"


# --------------------------------------------------------------------------
# search / page / eval
# --------------------------------------------------------------------------


def _row(page_id, path, section, snippet, score, confidence, last_verified):
    return {
        "page_id": page_id,
        "path": path,
        "section": section,
        "snippet": snippet,
        "score": round(float(score), 6),
        "confidence": confidence or "",
        "last_verified": last_verified or "",
    }


def search(cfg, query, k=5, domain=None, engine="auto"):
    """Top-k chunk hits by cosine similarity. Never raises for a missing or
    unreadable index — an empty list is the documented degraded answer."""
    try:
        k = max(0, min(int(k), MAX_K))
    except (TypeError, ValueError):
        return []
    if k == 0:
        return []
    conn = open_ro(cfg)
    if conn is None:
        return []
    try:
        # Embed the query with the index's own model, not the ambient default:
        # two different models' vectors are not comparable.
        model_name = _meta(conn, "model") or cfg.model_name
        try:
            embedder = make_embedder(model_name, cfg.index_dir / "models")
            vector = embedder.embed([query])[0]
        except Exception:  # noqa: BLE001 — a broken backend degrades to no hits
            return []
        if not any(vector):
            return []

        use_vec0 = engine == "vec0" or (
            engine == "auto" and _meta(conn, "vec0") == "1" and try_load_vec(conn)
        )
        if engine == "vec0" and not try_load_vec(conn):
            return []
        try:
            if use_vec0:
                return _search_vec0(conn, vector, k, domain)
            return _search_scan(conn, vector, k, domain)
        except (sqlite3.Error, struct.error):
            # A truncated or corrupt wiki.db is a stale-index problem, not a
            # caller error: the hook rebuilds it, and search stays empty.
            return []
    finally:
        conn.close()


def _search_scan(conn, vector, k, domain):
    sql = (
        "SELECT id, page_id, path, section, snippet, confidence, last_verified, "
        "embedding FROM chunks"
    )
    params = ()
    if domain:
        sql += " WHERE domain = ?"
        params = (domain,)
    scored = []
    for row in conn.execute(sql, params):
        score = sum(a * b for a, b in zip(vector, unpack(row[7])))
        scored.append((-score, row[0], row))
    scored.sort(key=lambda item: (item[0], item[1]))
    return [
        _row(r[1], r[2], r[3], r[4], -neg, r[5], r[6]) for neg, _id, r in scored[:k]
    ]


def _search_vec0(conn, vector, k, domain):
    # vec0 applies its own k before any join, so a domain filter has to ask for
    # the widest window and cut afterwards or it silently returns too few rows.
    want = MAX_K if domain else k
    sql = (
        "SELECT c.page_id, c.path, c.section, c.snippet, c.confidence, "
        "c.last_verified, v.distance FROM chunk_vec v JOIN chunks c ON c.id = v.rowid "
        "WHERE v.embedding MATCH ? AND k = ?"
    )
    params = [pack(vector), want]
    if domain:
        sql += " AND c.domain = ?"
        params.append(domain)
    sql += " ORDER BY v.distance"
    try:
        rows = conn.execute(sql, params).fetchall()
    except sqlite3.Error:
        return []
    return [_row(r[0], r[1], r[2], r[3], 1.0 - r[6], r[4], r[5]) for r in rows[:k]]


def page(cfg, page_id):
    conn = open_ro(cfg)
    if conn is None:
        return None
    try:
        row = conn.execute(
            "SELECT path FROM pages WHERE page_id = ? LIMIT 1", (page_id,)
        ).fetchone()
    except sqlite3.Error:
        return None
    finally:
        conn.close()
    if row is None:
        return None
    try:
        return (cfg.wiki_root / row[0]).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None


def evaluate(cfg, cases, k):
    hits = 0
    for case in cases:
        rows = search(cfg, case["query"], k)
        if any(row["page_id"] == case["expected_page_id"] for row in rows):
            hits += 1
    return hits, len(cases)


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def _cmd_search(cfg, args):
    rows = search(cfg, args.query, args.k, args.domain, args.engine)
    print(json.dumps(rows))
    return 0


def _cmd_page(cfg, args):
    body = page(cfg, args.page_id)
    if body is None:
        print("unknown page_id: %s" % args.page_id, file=sys.stderr)
        return 1
    sys.stdout.write(body)
    return 0


def _cmd_eval(cfg, args):
    with open(args.cases, encoding="utf-8") as fh:
        cases = json.load(fh)
    probe = open_ro(cfg)
    if probe is None:
        print("no index", file=sys.stderr)
        return 4
    probe.close()
    hits, total = evaluate(cfg, cases, args.k)
    recall = (hits / total) if total else 0.0
    print("recall@%d %.2f hits %d total %d" % (args.k, recall, hits, total))
    return 0


def main(argv):
    parser = argparse.ArgumentParser(
        prog="wiki-index.py", description="local vector index over the bundled wiki"
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--build", action="store_true", help="full rebuild")
    mode.add_argument("--incremental", action="store_true", help="changed pages only")
    mode.add_argument("--status", action="store_true", help="print the freshness token")

    sub = parser.add_subparsers(dest="command")

    p_search = sub.add_parser("search", help="query the index")
    p_search.add_argument("--query", required=True)
    p_search.add_argument("--k", type=int, default=5)
    p_search.add_argument("--domain", default=None)
    p_search.add_argument("--engine", default="auto", choices=("auto", "scan", "vec0"))
    p_search.add_argument("--json", action="store_true", help="accepted; JSON is the only output")

    p_page = sub.add_parser("page", help="print one page body")
    p_page.add_argument("--page-id", dest="page_id", required=True)

    p_eval = sub.add_parser("eval", help="Recall@k over a cases file")
    p_eval.add_argument("--cases", required=True)
    p_eval.add_argument("--k", type=int, default=5)

    args = parser.parse_args(argv)
    cfg = Config.from_env()

    if args.command == "search":
        return _cmd_search(cfg, args)
    if args.command == "page":
        return _cmd_page(cfg, args)
    if args.command == "eval":
        return _cmd_eval(cfg, args)
    if args.status:
        print(status(cfg))
        return 0
    if args.incremental:
        return incremental(cfg)
    if args.build:
        return build(cfg)
    parser.print_usage(sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
