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
- _(further bugs fixed in subsequent commits; see git log.)_
