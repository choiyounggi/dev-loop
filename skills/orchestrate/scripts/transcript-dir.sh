# transcript-dir.sh — the Claude Code CLI's transcript-directory rule, shared by launch-session.sh, send-prompt.sh and token-report.sh (#320). Source it; never execute it.
#
# Root: ${CLAUDE_CONFIG_DIR} when non-empty, else $HOME/.claude when HOME is
# non-empty; transcripts live in <root>/projects/<name>.
# Name: the path with every UTF-16 code unit outside A-Za-z0-9 replaced by '-'
# (a code point above U+FFFF gives two dashes); a name over 200 characters is
# matched as <first 200>-* because the CLI appends a hash.
# The path is mapped exactly as given; the helper never cd's into it or
# resolves symlinks — callers pass a physical path.
# The helper never reads LO_TRANSCRIPT_DIR; overrides belong to the caller.
#
# transcript_dir_derive PATH — rc 0: sets td_root and td_name. rc 1: sets
#   td_err to exactly one of empty-path, no-home, no-jq, nfd.
# transcript_dir_resolve ROOT NAME — always rc 0: sets td_want (ROOT/NAME, or
#   the pattern ROOT/<first 200>-* for a longer name), td_dir (ROOT/NAME
#   unchecked for a short name; the one matching dir, or '' for zero or several
#   matches) and td_amb (the match count when above 1, else 0).
#
# Function names, arguments, variables and td_err tokens are a stable contract
# (t2 / #321 edits launch-session.sh around these calls).

transcript_dir_derive() { # $1 = path -> rc 0 (td_root, td_name) or rc 1 (td_err)
  td_root=""; td_name=""; td_err=""
  if [ -z "${1:-}" ]; then td_err=empty-path; return 1; fi
  _td_cfg="${CLAUDE_CONFIG_DIR:-}"
  if [ -z "$_td_cfg" ] && [ -n "${HOME:-}" ]; then _td_cfg="$HOME/.claude"; fi
  if [ -z "$_td_cfg" ]; then td_err=no-home; return 1; fi
  if ! jq -n 'empty' >/dev/null 2>&1; then td_err=no-jq; return 1; fi
  _td_map='[$p | explode[] | if (. >= 48 and . <= 57) or (. >= 65 and . <= 90) or (. >= 97 and . <= 122) then . elif . > 65535 then (45, 45) else 45 end] | implode'
  _td_nfd='[$p | explode[] | select((. >= 768 and . <= 879) or (. >= 4352 and . <= 4607) or (. >= 6832 and . <= 6911) or (. >= 7616 and . <= 7679) or (. >= 8400 and . <= 8447) or (. >= 65056 and . <= 65071))] | length > 0'
  if [ "$(jq -n --arg p "$1" "$_td_nfd" 2>/dev/null)" = "true" ]; then td_err=nfd; return 1; fi
  _td_n=$(jq -rn --arg p "$1" "$_td_map" 2>/dev/null) || { td_err=no-jq; return 1; }
  td_root="$_td_cfg/projects"; td_name="$_td_n"
  return 0
}

transcript_dir_resolve() { # $1 = root, $2 = name -> td_want, td_dir ('' = none or ambiguous), td_amb
  td_dir=""; td_amb=0
  if [ "${#2}" -le 200 ]; then td_want="$1/$2"; td_dir="$td_want"; return 0; fi
  _td_cut=$(printf '%s' "$2" | cut -c1-200)
  td_want="$1/$_td_cut-*"
  _td_c=0
  case $- in *f*) _td_f=1; set +f ;; *) _td_f=0 ;; esac
  for _td_d in "$1/$_td_cut"-*; do
    [ -d "$_td_d" ] || continue
    _td_c=$((_td_c + 1)); td_dir="$_td_d"
  done
  if [ "$_td_f" -eq 1 ]; then set -f; fi
  if [ "$_td_c" -gt 1 ]; then td_amb=$_td_c; td_dir=""; fi
  return 0
}
