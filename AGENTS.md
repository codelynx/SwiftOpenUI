# Agent Workflow

This file defines the collaboration protocol for multi-platform feature work in SwiftOpenUI.

> **Before you start:** skim [`docs/cross-platform-changelog.md`](docs/cross-platform-changelog.md) for shared-surface changes another backend landed that may affect yours (symbol map, core `View`/`Layout` types, view-host, cross-cutting behavior). Append an entry there whenever you change shared surface.

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

## Concurrent Sessions

Several agent sessions may run against this repo at once. They share one working
directory unless told otherwise, which collides in two ways: a branch switch moves the
checkout under another session, and two `swift build` / `swift test` runs race in the
same build directory.

- One session owns the main checkout. Every other concurrent session works in its own
  git worktree, with its own build directory. Prefer moving the session that has no
  in-flight branches.
- Checkout ownership must be explicit — stated by the user, or agreed between sessions.
  Do not infer it from an agent or session listing, which may omit independent
  sessions. `git worktree list` shows which checkouts exist, not who is working in one.
  Until ownership is established, treat the main checkout as unavailable for changes or
  builds. A handoff may record ownership; it does not silently transfer it.
- Never switch, reset, or delete a branch in a checkout another session owns. Ask that
  session to move itself.
- Never push another session's branch. An unpushed branch is usually waiting on its own
  user's approval, not an oversight.
- Hand work between sessions as a cherry-pickable commit, reported in the
  `Required Handoff Format` above. Worktrees share the object store, so
  `git cherry-pick <sha>` needs no fetch or push.
- Before removing a worktree, confirm it is clean and preserve its exact HEAD with a
  branch or tag outside the cleanup tool's deletion scope; afterwards, verify that ref
  still resolves to the recorded commit. `git worktree remove` keeps the worktree's
  branch, but tooling that deletes the branch along with the worktree — the harness
  `ExitWorktree` does — or a tip left detached can leave those commits without a
  durable reference. Matching file contents (an empty `git diff`) is not evidence that
  commits are reachable. A clean status does not cover ignored or untracked files, so
  copy out any build output or local files you still need first.

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
