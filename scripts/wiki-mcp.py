#!/usr/bin/env python3
"""dev-loop-wiki MCP: two tools over the local wiki index (scripts/wiki-index.py).

Exactly two tools, on purpose. A tool definition costs context in every session
whether or not it is called, so the surface stays at the two calls that matter:
find the page, then read it.

stdout is the JSON-RPC channel — diagnostics go to stderr only.
"""

import importlib.util
import pathlib
import sys
from typing import Optional

# Loading a sibling by path byte-compiles it, which would drop a __pycache__
# directory into the installed plugin. The index dir is the only place this
# feature may write.
sys.dont_write_bytecode = True

_HERE = pathlib.Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("wiki_index", _HERE / "wiki-index.py")
wiki_index = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(wiki_index)

from mcp.server.mcpserver import MCPServer  # noqa: E402 — after the sibling module loads
from mcp.server.mcpserver.exceptions import ToolError  # noqa: E402

server = MCPServer("dev-loop-wiki")


@server.tool()
def wiki_search(query: str, k: int = 5, domain: Optional[str] = None) -> list[dict]:
    """Semantic search over the bundled dev-loop wiki.

    Returns up to k chunk hits as objects with page_id, path, section, snippet,
    score, confidence and last_verified — never a page body. An index that is
    absent or still building returns an empty list rather than an error.
    """
    return wiki_index.search(wiki_index.Config.from_env(), query, k, domain, "auto")


@server.tool()
def wiki_page(page_id: str) -> str:
    """Full markdown body of one wiki page, by its frontmatter id.

    Use wiki_search first to find the page_id.
    """
    body = wiki_index.page(wiki_index.Config.from_env(), page_id)
    if body is None:
        # ToolError, not a bare exception: the SDK forwards this message to the
        # caller and replaces any other exception's text with a generic one.
        raise ToolError("unknown page_id: %s" % page_id)
    return body


if __name__ == "__main__":
    print("dev-loop-wiki: serving stdio", file=sys.stderr)
    server.run(transport="stdio")
