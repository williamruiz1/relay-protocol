#!/bin/bash
# Session Discipline Verification (Stop hook)
# Reads surface definitions from .claude/protocol-config.json and checks
# that each was updated when source files changed.
#
# Lightweight generic version — no schema validation, no reconcile, no
# burn-in tracking. Extend this hook in your workspace if needed.
#
# Exit 0 = allow | Exit 2 = block (stderr fed back to agent)

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

CONFIG=".claude/protocol-config.json"
[ ! -f "$CONFIG" ] && exit 0

HEAD_SHA=$(git rev-parse HEAD 2>/dev/null)
[ -z "$HEAD_SHA" ] && exit 0

# Load config
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
      console.log('S' + i + '_LABEL=' + JSON.stringify(s.label || s.name));
      console.log('S' + i + '_MATCH=' + JSON.stringify(s.match || 'exact'));
      console.log('S' + i + '_PATHS=' + JSON.stringify(
        s.paths ? s.paths.join('|') : (s.path || '')
      ));
    });
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

# Check each surface
MISSING=""
i=0
while [ "$i" -lt "$SURFACE_COUNT" ]; do
  eval "LABEL=\$S${i}_LABEL"
  eval "MATCH=\$S${i}_MATCH"
  eval "PATHS=\$S${i}_PATHS"

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

  [ "$FOUND" -eq 0 ] && MISSING="${MISSING}  - ${LABEL} (${PATHS})\n"
  i=$((i + 1))
done

if [ -n "$MISSING" ]; then
  printf 'Session protocol: surfaces missing updates:\n\n' >&2
  printf '%b' "$MISSING" >&2
  printf '\nUpdate the missing surfaces before finishing.\n' >&2
  exit 2
fi

exit 0
