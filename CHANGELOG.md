# Changelog

All notable changes to git-native-agents are documented here.
This project adheres to [Keep a Changelog](https://keepachangelog.com/) semantics.

## [Unreleased] — production hardening round 4 (2026-07-11)

### Added
- `tests/run.sh`: self-contained test suite (no external framework dependency).
  Exercises spawn/send/tick/remember/recall/think/decide/fleet and their error
  paths. Each test runs against an isolated sandbox copy of the repo.

### Fixed
- **fleet: stray "0" line in status output.** `fleet_status` counted thought
  branches with `git branch | grep -c 'thought/' || echo "0"`. When an agent
  had no thought branches, `grep -c` prints `0` *and* exits 1, so the `|| echo
  "0"` ran too, emitting a second bare `0` line after every agent. Replaced with
  `|| true`, which keeps `grep -c`'s own count output without the duplicate.
- **recall: returns exit 0 on missing memory.** `recall` printed an error via
  the `fail` helper (which uses `echo`, exit 0) and never returned non-zero, so
  callers could not detect a failed lookup. Now returns 1 when the memory tag
  is absent.
- **remember/recall/think: raw `cd` error on unknown agent.** Unlike `send` and
  `tick` (which validated the agent and printed a clean message), these commands
  `cd`'d into the workspace directly. Under `set -e` an unknown agent produced a
  raw `cd: ... No such file or directory` with a line-number leak instead of
  `✗ Agent 'X' not found`. Added a shared `require_agent` guard.
- **decide: silent abort on missing thought branch.** Deciding a topic whose
  `thought/<topic>` branch didn't exist made both `git merge` attempts fail; under
  `set -e` the script aborted with no useful message. Now verifies the branch
  exists first and returns a clean `✗ Agent 'X' has no thought branch: <topic>`.
- **decide: fast-forward dropped the merge commit.** `decide` merged with a plain
  `git merge`, which fast-forwards when the main branch is an ancestor of the
  thought branch (the common single-commit case). A fast-forward silently discards
  the `-m "decide: merged <topic>"` message and produces *no* merge commit — but
  the README documents that merge commit as the auditable decision record. Now
  uses `--no-ff` so a real two-parent merge commit is always created. `decide`
  also gained the same `require_agent` guard as the other commands.
