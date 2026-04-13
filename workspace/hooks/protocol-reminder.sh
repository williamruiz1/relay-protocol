#!/bin/bash
# Protocol Reminder (UserPromptSubmit hook)
# Emits a short reminder about planning surfaces when git changes are detected.

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

# Only remind if there are active changes
DIRTY=$(git status --porcelain 2>/dev/null | head -1)
[ -z "$DIRTY" ] && exit 0

CONFIG=".claude/protocol-config.json"
if [ -f "$CONFIG" ]; then
  SURFACE_NAMES=$(node -e "
    try {
      const c = JSON.parse(require('fs').readFileSync('$CONFIG','utf8'));
      const names = (c.surfaces || []).map(s => s.label || s.name);
      process.stdout.write(names.join(', '));
    } catch(e) { process.stdout.write(''); }
  " 2>/dev/null)

  if [ -n "$SURFACE_NAMES" ]; then
    printf 'Session protocol: source files changed. Before closing, update: %s.\n' "$SURFACE_NAMES"
    printf 'See ~/.claude/rules/session-protocol.md for the full protocol.\n'
  fi
fi

exit 0
