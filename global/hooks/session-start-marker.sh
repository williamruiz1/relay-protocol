#!/bin/bash
# Session Start Marker (global)
# Runs on SessionStart — writes the current HEAD sha to .claude/.hook-session-start
# so Stop hooks can compute diffs against the actual session boundary instead
# of merge-base (which mis-attributes prior sessions' unpushed work).
#
# File is workspace-local and ephemeral. Each new session resets its baseline.

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

# Only run in git repos
HEAD_SHA=$(git rev-parse HEAD 2>/dev/null)
if [ -n "$HEAD_SHA" ]; then
  mkdir -p .claude
  printf '%s\n' "$HEAD_SHA" > .claude/.hook-session-start
fi

exit 0
