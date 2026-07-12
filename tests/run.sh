#!/bin/bash
# Test suite for git-native-agents orchestrator.sh
#
# Self-contained: no external test framework (bats, shunit2, ...) required.
# Each test runs against a fresh sandbox copy of the repo so tests are
# isolated and never touch the caller's working tree.
#
# Usage:  ./tests/run.sh
# Exit:   0 if every assertion passed, 1 otherwise.
set -uo pipefail

ORIG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_NAME="orchestrator.sh"
SANDBOX=""
PASS=0
FAIL=0
FAILURES=()

# ---------------------------------------------------------------------------
# Assertion helpers
# ---------------------------------------------------------------------------

assert_exit() {
    # assert_exit <expected_code> -- <cmd...>
    local expected="$1"; shift
    [ "${1:-}" = "--" ] && shift
    "$@" >/dev/null 2>&1
    local actual=$?
    if [ "$actual" -eq "$expected" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        FAILURES+=("expected exit $expected, got $actual -- $*")
    fi
}

assert_eq() {
    local expected="$1" actual="$2" label="${3:-value}"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        FAILURES+=("$label: expected [$expected] got [$actual]")
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" label="${3:-output}"
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        FAILURES+=("$label: expected to contain [$needle]")
    fi
}

assert_not_contains() {
    local haystack="$1" needle="$2" label="${3:-output}"
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        FAIL=$((FAIL+1))
        FAILURES+=("$label: should NOT contain [$needle] but did")
    else
        PASS=$((PASS+1))
    fi
}

assert_file_exists() {
    local f="$1" label="${2:-file}"
    if [ -f "$f" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        FAILURES+=("$label: expected file [$f] to exist")
    fi
}

# ---------------------------------------------------------------------------
# Sandbox: fresh copy of the repo so agent workdirs don't leak across tests
# ---------------------------------------------------------------------------

setup() {
    SANDBOX="$(mktemp -d)"
    cp "$ORIG_DIR/$SCRIPT_NAME" "$SANDBOX/"
    mkdir -p "$SANDBOX/registry"
    : > "$SANDBOX/registry/agents.txt"
    rm -rf "$SANDBOX/agents"
    mkdir -p "$SANDBOX/agents"
    cd "$SANDBOX" || exit 1
}

teardown() {
    cd "$ORIG_DIR" || exit 1
    [ -n "$SANDBOX" ] && rm -rf "$SANDBOX"
    SANDBOX=""
}

# Convenience: run the orchestrator inside the current sandbox.
ora() { bash "$SANDBOX/$SCRIPT_NAME" "$@"; }

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_spawn_creates_agent_repo() {
    setup
    ora spawn alice worker >/dev/null 2>&1
    assert_exit 0 -- test -d agents/alice
    assert_file_exists agents/alice/AGENT.yaml "manifest"
    assert_exit 0 -- test -d agents/alice/inbox
    assert_exit 0 -- test -d agents/alice/outbox
    assert_exit 0 -- test -d agents/alice/memory
    # registry must list the agent
    assert_contains "$(cat registry/agents.txt)" "agents/alice" "registry"
    # AGENT.yaml carries the role and initial tick
    assert_contains "$(cat agents/alice/AGENT.yaml)" "role: worker" "manifest role"
    assert_contains "$(cat agents/alice/AGENT.yaml)" "tick: 0" "manifest tick"
    teardown
}

test_spawn_refuses_duplicate() {
    setup
    ora spawn alice worker >/dev/null 2>&1
    assert_exit 1 -- ora spawn alice worker
    teardown
}

test_send_writes_inbox_message() {
    setup
    ora spawn alice coordinator >/dev/null 2>&1
    ora spawn bob worker >/dev/null 2>&1
    ora send alice bob "hello there" >/dev/null 2>&1
    local n; n=$(ls agents/bob/inbox/*.md 2>/dev/null | wc -l)
    assert_eq 1 "$n" "one message in inbox"
    assert_contains "$(cat agents/bob/inbox/*.md)" "from: alice" "message header"
    assert_contains "$(cat agents/bob/inbox/*.md)" "message: hello there" "message body"
    teardown
}

test_send_unknown_recipient_fails() {
    setup
    ora spawn alice coordinator >/dev/null 2>&1
    assert_exit 1 -- ora send alice ghost "hi"
    teardown
}

test_tick_processes_inbox() {
    setup
    ora spawn alice coordinator >/dev/null 2>&1
    ora spawn bob worker >/dev/null 2>&1
    ora send alice bob "do the thing" >/dev/null 2>&1
    ora tick bob >/dev/null 2>&1
    # inbox cleared of *.md (moved to .processed)
    local inbox_n; inbox_n=$(ls agents/bob/inbox/*.md 2>/dev/null | wc -l)
    assert_eq 0 "$inbox_n" "inbox cleared after tick"
    # outbox has a response
    local outbox_n; outbox_n=$(ls agents/bob/outbox/*.md 2>/dev/null | wc -l)
    assert_eq 1 "$outbox_n" "one outbox response"
    assert_contains "$(cat agents/bob/outbox/*.md)" "do the thing" "response echoes body"
    # processed copy retained
    local proc_n; proc_n=$(ls agents/bob/inbox/.processed-* 2>/dev/null | wc -l)
    assert_eq 1 "$proc_n" "one processed copy"
    # tick counter incremented
    assert_contains "$(cat agents/bob/AGENT.yaml)" "tick: 1" "tick incremented"
    teardown
}

test_tick_empty_inbox_is_idle() {
    setup
    ora spawn alice worker >/dev/null 2>&1
    assert_exit 0 -- ora tick alice
    teardown
}

test_tick_unknown_agent_fails() {
    setup
    assert_exit 1 -- ora tick ghost
    teardown
}

test_remember_creates_tagged_memory() {
    setup
    ora spawn alice worker >/dev/null 2>&1
    ora remember alice color blue >/dev/null 2>&1
    assert_file_exists agents/alice/memory/color.txt "memory file"
    assert_eq "blue" "$(cat agents/alice/memory/color.txt)" "memory value"
    # git tag pinned
    assert_contains "$(cd agents/alice && git tag -l)" "memory/color" "memory tag"
    teardown
}

test_recall_retrieves_memory() {
    setup
    ora spawn alice worker >/dev/null 2>&1
    ora remember alice color blue >/dev/null 2>&1
    local out; out=$(ora recall alice color 2>/dev/null)
    assert_contains "$out" "blue" "recall value"
    teardown
}

test_think_creates_thought_branch() {
    setup
    ora spawn alice worker >/dev/null 2>&1
    ora think alice mytopic >/dev/null 2>&1
    assert_contains "$(cd agents/alice && git branch)" "thought/mytopic" "thought branch"
    teardown
}

test_decide_merges_thought() {
    setup
    ora spawn alice worker >/dev/null 2>&1
    ora think alice mytopic >/dev/null 2>&1
    assert_exit 0 -- ora decide alice mytopic
    # After decide the thought branch content must be on the agent's main line.
    assert_file_exists agents/alice/thought-mytopic.md "thought artifact on main"
    # Note: current implementation fast-forwards, so no merge commit is produced.
    # The --no-ff merge-commit assertion is added by the decide fix.
    teardown
}

test_fleet_lists_registered_agents() {
    setup
    ora spawn alice coordinator >/dev/null 2>&1
    ora spawn bob worker >/dev/null 2>&1
    local out; out=$(ora fleet 2>/dev/null)
    assert_contains "$out" "alice" "fleet lists alice"
    assert_contains "$out" "bob" "fleet lists bob"
    teardown
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

main() {
    local tests=(
        test_spawn_creates_agent_repo
        test_spawn_refuses_duplicate
        test_send_writes_inbox_message
        test_send_unknown_recipient_fails
        test_tick_processes_inbox
        test_tick_empty_inbox_is_idle
        test_tick_unknown_agent_fails
        test_remember_creates_tagged_memory
        test_recall_retrieves_memory
        test_think_creates_thought_branch
        test_decide_merges_thought
        test_fleet_lists_registered_agents
    )
    echo "Running ${#tests[@]} tests..."
    for t in "${tests[@]}"; do
        local before=$FAIL
        printf '  %-40s' "$t"
        "$t"
        if [ "$FAIL" -gt "$before" ]; then
            printf 'FAIL (%d)\n' $((FAIL - before))
        else
            printf 'ok\n'
        fi
    done

    echo
    echo "Results: ${PASS} passed, ${FAIL} failed"
    if [ "$FAIL" -gt 0 ]; then
        echo
        echo "Failures:"
        for f in "${FAILURES[@]}"; do echo "  - $f"; done
        exit 1
    fi
    exit 0
}

main "$@"
