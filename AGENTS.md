# Agent Workflow

This file defines the collaboration protocol for multi-platform feature work in SwiftOpenUI.

## Branch Roles

- `develop`
  - integration branch
  - coordinator merges verified work here
- `batch/*`
  - created from the coordinator-declared batch base
  - used for one bounded feature batch
  - intended to merge once
- `fix/*`
  - created from current `develop`
  - used for follow-up fixes after a batch has already started landing
  - intended for quick merge or cherry-pick

## Required Handoff Format

Every platform worker handoff must include:

- Branch
- Commit
- Base commit
- Verified remote base hash
- Changed files
- What was implemented
- What remains partial
- Tests run
- Whether the result is intended for merge or cherry-pick

## Ownership Rules

Platform workers own:

- backend-specific renderer files
- backend-specific tests

Coordinator owns:

- core API design
- integration on `develop`
- merge conflict resolution
- implementation tracker regeneration
- parity matrix updates
- repo-level status docs

## Shared Docs Workers Must Not Edit As Final Truth

- `docs/api/implementation-tracker/**`
- `docs/architecture/swiftui-parity-matrix.md`
- `CLAUDE.md`

Workers may mention expected doc impacts in the handoff, but coordinator decides the final shared-truth update.

## Merge Protocol

1. Coordinator creates and pushes the batch base.
2. Coordinator verifies the pushed remote ref with:
   - `git ls-remote --heads origin <branch>`
   - only then sends the worker handoff
3. Worker verifies the base before doing any implementation:
   - `git fetch origin`
   - `git switch -C <worker-branch> origin/<base-branch>`
   - `git rev-parse HEAD`
   - if the hash differs from the handoff hash, stop and report stale base
4. Platform branches start from that exact base commit.
5. Coordinator reviews and merges clean platform branches.
6. Once any branch from that batch is merged into `develop`, remaining sibling branches are stale by default.
7. After that point, additional platform work should come back as:
   - a new branch from current `develop`, or
   - a focused cherry-pickable commit

## Practical Rule

If a branch contains valid backend work but is based on an older batch base and also carries stale state from other files, do not merge the branch head.

Cherry-pick the focused fix commit onto `develop` instead.
