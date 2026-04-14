# ADR 001: Session Exemption Mechanism

**Status:** Accepted
**Date:** 2026-04-14

## Context

The Stop hook enforces that planning surfaces are updated whenever source files change. But some sessions legitimately don't need to touch every surface:

- **Infra/ops sessions** — Dockerfile, CI config, build scripts. No user-facing change, no tracker row, no state inventory delta.
- **Doc-only specs** — A spec that hasn't yet earned a roadmap entry (the feature is still being designed).
- **Hotfixes** — Emergency one-liners that don't warrant a full handoff/state update.

When the hook has no escape hatch, agents get stuck in a loop: they can't close the session and they don't want to fabricate surface updates. This wastes cycles and trains agents to game the system (touch the file with a no-op edit just to satisfy the hook).

Observed failure mode (session with VS Code agent, 2026-04-14): a specs-only commit triggered 10+ Stop-hook iterations. Agent refused to act unilaterally and waited for user direction, but didn't know an exemption mechanism existed.

## Decision

Support a per-session exemption file: `.claude/session-config.json` (gitignored, ephemeral).

```json
{
  "exemptSurfaces": ["roadmap", "state"],
  "reason": "Doc-only spec session — no endpoint/schema changes"
}
```

The Stop hook reads this file and skips the listed surfaces (by `name`) from enforcement.

### Key properties

- **Ephemeral** — the file is gitignored and resets per session. Exemptions don't leak across sessions.
- **Opt-in per surface** — not a blanket skip. The agent still has to satisfy all non-exempt surfaces.
- **Reason required** — the `reason` field is mandatory; it surfaces in the handoff doc and trains the agent to think about *why* it's exempting.
- **Surface-level flag** — each surface in `protocol-config.json` that supports exemption declares `"exemptable": true`. Non-exemptable surfaces (e.g., handoff doc) cannot be skipped.

### Discoverability

When the Stop hook blocks, its error message must tell the agent about the escape hatch:

```
Planning surfaces missing updates:
  - STATE.json (.claude/STATE.json)
  - ROADMAP_TREE (tools/internal-roadmap/roadmap.ts)

If this session genuinely doesn't need these surfaces, write:
  .claude/session-config.json
  { "exemptSurfaces": ["state", "roadmap"], "reason": "..." }

Otherwise, update the missing surfaces before finishing.
```

This converts a stuck loop into a two-option decision: satisfy the surface or exempt it with a documented reason.

## Consequences

**Positive:**
- Agents have a clear, documented way out of the loop
- Exemption reasons create an audit trail (they land in the handoff)
- Discoverability is baked into the blocking message — no separate docs to read

**Negative:**
- Adds one more config file per workspace (small)
- Agents could abuse exemptions if not reviewed — mitigated by the `reason` field landing in handoffs

**Neutral:**
- The workspace-layer hook must read and honor `session-config.json`; the template hook will implement this. Workspaces extending the template (like PPM) must adopt the new schema.

## Alternatives Considered

1. **Silent pass when nothing relevant changed** — brittle; hard to distinguish "nothing relevant" from "agent forgot."
2. **Time-based cooldown** — if the hook fires 3x, exit 0. Trains agents that persistence beats the hook.
3. **Boolean `skipAll` flag** — too coarse; no audit trail.

The per-surface exemption with reason provides the right balance: explicit, auditable, fine-grained.
