# Educational rewrite notes

This file explains the choices made while rewriting `README.md` for the educational-writing standard in `STYLE_BRIEF.md`.

## 1. Opening with the Google Doc vs. git repo analogy

The brief asks to motivate before mechanizing. Most readers have used git only as code storage, so the README opens with a comparison almost everyone has felt: a live shared document vs. a commit-based repository. The analogy is not decorative — it maps directly onto the design: git's commits become the audit trail, offline work becomes possible because every agent has its own repository, and rollback is a normal git operation rather than a special feature.

## 2. Defining jargon at first use

Every technical term is defined inline the first time it appears:

- **Agent repository**: introduced as a normal git repo with a concrete path.
- **Message**: shown as an actual file with the headers the orchestrator writes.
- **Tick**: described as one pass through `inbox/*.md`, including the move to `.processed-*`.
- **Memory**: explained as `memory/{key}.txt` plus a tag.
- **Thought branch**: defined as a branch literally named `thought/<topic>`, matching `orchestrator.sh`.
- **Merge-based decision**: defined carefully. The source only uses `git merge` inside the `decide` command to merge a single agent's thought branch; there is no multi-agent voting protocol. The README therefore calls it a *decision* (an agent adopting a line of reasoning) rather than implying a distributed consensus algorithm.

## 3. Accuracy checks against the source

The rewrite was checked against `orchestrator.sh` rather than trusting the previous README:

- Messages are committed files in `inbox/`, not git notes. The previous README and the script's own header incorrectly said "git notes"; the new README says "committed files."
- Thought branches are named `thought/<topic>` and create `thought-{topic}.md` files.
- `decide` merges to `main` or `master`, whichever exists.
- `remember` uses the tag name `memory/{key}`.
- `recall` uses `git show memory/{key}:memory/{key}.txt`.
- `broadcast` skips the sender and sends to everyone else.
- `fleet` reads `registry/agents.txt`.

## 4. Scaling and concurrency caveat

The previous README claimed the system "scales cleanly to 5–50 agents." That was removed because it could not be verified against the current source. Instead, the new README states the verified behavior:

- There is no file locking or atomic queue around git operations.
- Concurrent sends to the same agent repository collide on git's `index.lock`.
- The system is appropriate for a small number of agents and serial or low-concurrency access.

The specific "11 of 12 concurrent writers" figure from the earlier deep-dive was not found in the repo's git history or any `CHANGELOG`, so it is not cited as a verified repo fact. The README describes the underlying mechanism that produces such contention without repeating an unsubstantiated number.

## 5. License correction

The previous README said "MIT." The repository's `LICENSE` file is Apache-2.0, so the new README says Apache-2.0.

## 6. Code examples

Every command in the Quick Start section was run against a fresh copy of the current source before the rewrite was finalized: `spawn`, `send`, `tick`, `remember`, `recall`, `think`, `decide`, `fleet`, and `broadcast`.

## 7. What was not changed

No source code was modified. The empty tracked agent directories and the existing `registry/agents.txt` (which contains absolute paths from another environment) were left untouched because they were outside the scope of the README rewrite.
