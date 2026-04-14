#!/bin/bash
# Session Discipline Verification (Stop hook)
# Reads surface definitions from .claude/protocol-config.json and checks
# that each was updated when source files changed.
#
# Supports per-session exemptions via .claude/session-config.json:
#   { "exemptSurfaces": ["state", "roadmap"], "reason": "..." }
# Only surfaces with "exemptable": true in protocol-config.json can be exempted.
#
# Lightweight generic version — no schema validation, no reconcile, no
# burn-in tracking. Extend this hook in your workspace if needed.
#
# Exit 0 = allow | Exit 2 = block (stderr fed back to agent)

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

CONFIG=".claude/protocol-config.json"
SESSION_CONFIG=".claude/session-config.json"
[ ! -f "$CONFIG" ] && exit 0

HEAD_SHA=$(git rev-parse HEAD 2>/dev/null)
[ -z "$HEAD_SHA" ] && exit 0

# Load config (both protocol-config and session-config exemptions)
CONFIG_DATA=$(node -e "
  const fs = require('fs');
  try {
    const c = JSON.parse(fs.readFileSync('$CONFIG', 'utf8'));
    const sp = (c.sourcePatterns || []).join('|');
    console.log('SOURCE_RE=' + JSON.stringify(sp));
    const ex = (c.sourceExclusions || []);
    console.log('SOURCE_EXCLUSIONS=' + JSON.stringify(ex.join('\n')));
    console.log('SURFACE_COUNT=' + (c.surfaces || []).length);
    (c.surfaces || []).forEach((s, i) => {
      console.log('S' + i + '_NAME=' + JSON.stringify(s.name || ''));
      console.log('S' + i + '_LABEL=' + JSON.stringify(s.label || s.name));
      console.log('S' + i + '_MATCH=' + JSON.stringify(s.match || 'exact'));
      console.log('S' + i + '_EXEMPTABLE=' + (s.exemptable ? '1' : '0'));
      console.log('S' + i + '_PATHS=' + JSON.stringify(
        s.paths ? s.paths.join('|') : (s.path || '')
      ));
    });

    // Session-level exemptions (per-session, ephemeral)
    let exemptList = [];
    try {
      const sc = JSON.parse(fs.readFileSync('$SESSION_CONFIG', 'utf8'));
      exemptList = Array.isArray(sc.exemptSurfaces) ? sc.exemptSurfaces : [];
    } catch(e) { /* session-config absent or unreadable — no exemptions */ }
    console.log('EXEMPT_NAMES=' + JSON.stringify(exemptList.join('|')));
  } catch(e) { console.log('SURFACE_COUNT=0'); }
" 2>/dev/null)

[ -z "$CONFIG_DATA" ] && exit 0
eval "$CONFIG_DATA"
[ "$SURFACE_COUNT" -eq 0 ] && exit 0

# Determine baseline
BASE=""
if [ -f .claude/.hook-session-start ]; then
  MARKER_SHA=$(head -1 .claude/.hook-session-start 2>/dev/null | tr -d '[:space:]')
  if [ -n "$MARKER_SHA" ] && git cat-file -e "$MARKER_SHA" 2>/dev/null; then
    BASE="$MARKER_SHA"
  fi
fi

if [ -z "$BASE" ]; then
  for candidate in main master; do
    if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
      BASE=$(git merge-base HEAD "$candidate" 2>/dev/null)
      break
    fi
  done
fi

# Collect changed files
STAGED=$(git diff --name-only --cached 2>/dev/null)
LOCAL_COMMITS=""
if [ -n "$BASE" ] && [ "$BASE" != "$HEAD_SHA" ]; then
  LOCAL_COMMITS=$(git diff --name-only "$BASE" HEAD 2>/dev/null)
fi
ALL_CHANGED=$(printf '%s\n%s\n' "$STAGED" "$LOCAL_COMMITS" | sort -u | grep -v '^$')
[ -z "$ALL_CHANGED" ] && exit 0

# Check for source changes
SOURCE_CHANGES=$(printf '%s\n' "$ALL_CHANGED" | grep -E "$SOURCE_RE")
if [ -n "$SOURCE_EXCLUSIONS" ] && [ -n "$SOURCE_CHANGES" ]; then
  SOURCE_CHANGES=$(printf '%s\n' "$SOURCE_CHANGES" | grep -vF "$SOURCE_EXCLUSIONS" | head -1)
fi
[ -z "$SOURCE_CHANGES" ] && exit 0

# Include worktree changes
WORKTREE_CHANGED=$(git status --porcelain 2>/dev/null | awk '{
  line=substr($0, 4)
  arrow=index(line, " -> ")
  if (arrow > 0) { print substr(line, arrow+4) } else { print line }
}')
SURFACES_CHANGED=$(printf '%s\n%s\n' "$ALL_CHANGED" "$WORKTREE_CHANGED" | sort -u | grep -v '^$')

# Helper: is this surface name in the exempt list?
is_exempt() {
  local name="$1"
  [ -z "$EXEMPT_NAMES" ] && return 1
  for e in $(printf '%s' "$EXEMPT_NAMES" | tr '|' ' '); do
    [ "$e" = "$name" ] && return 0
  done
  return 1
}

# Check each surface
MISSING=""
MISSING_NAMES=""
i=0
while [ "$i" -lt "$SURFACE_COUNT" ]; do
  eval "NAME=\$S${i}_NAME"
  eval "LABEL=\$S${i}_LABEL"
  eval "MATCH=\$S${i}_MATCH"
  eval "PATHS=\$S${i}_PATHS"
  eval "EXEMPTABLE=\$S${i}_EXEMPTABLE"

  # Skip if exempted this session (only exemptable surfaces can be skipped)
  if [ "$EXEMPTABLE" = "1" ] && is_exempt "$NAME"; then
    i=$((i + 1))
    continue
  fi

  FOUND=0
  case "$MATCH" in
    prefix)
      printf '%s\n' "$SURFACES_CHANGED" | grep -q "^${PATHS}" && FOUND=1
      ;;
    exact)
      printf '%s\n' "$SURFACES_CHANGED" | grep -qF "$PATHS" && FOUND=1
      ;;
    anyOf)
      for p in $(printf '%s' "$PATHS" | tr '|' ' '); do
        printf '%s\n' "$SURFACES_CHANGED" | grep -qF "$p" && FOUND=1 && break
      done
      ;;
  esac

  if [ "$FOUND" -eq 0 ]; then
    MISSING="${MISSING}  - ${LABEL} (${PATHS})\n"
    if [ "$EXEMPTABLE" = "1" ]; then
      MISSING_NAMES="${MISSING_NAMES}${NAME} "
    fi
  fi
  i=$((i + 1))
done

if [ -n "$MISSING" ]; then
  printf 'Session protocol: surfaces missing updates:\n\n' >&2
  printf '%b' "$MISSING" >&2

  # Tell the agent about the escape hatch if any missing surfaces are exemptable
  if [ -n "$MISSING_NAMES" ]; then
    EXEMPT_LIST=$(printf '%s' "$MISSING_NAMES" | tr ' ' ',' | sed 's/,$//' | sed 's/,/", "/g')
    printf '\nIf this session genuinely does not need these surfaces, create:\n' >&2
    printf '  .claude/session-config.json\n' >&2
    printf '  { "exemptSurfaces": ["%s"], "reason": "<brief reason>" }\n' "$EXEMPT_LIST" >&2
    printf '\nOtherwise, update the missing surfaces before finishing.\n' >&2
  else
    printf '\nUpdate the missing surfaces before finishing.\n' >&2
  fi
  exit 2
fi

exit 0
