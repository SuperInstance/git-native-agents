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
- _(further bugs fixed in subsequent commits; see git log.)_
