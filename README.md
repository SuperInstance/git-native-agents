# Git-Native Agents

Most people who have used git know it as the place their code lives. This project treats git as the place where *agents live and talk to each other*.

## The intuition: coordination without a live server

Think about the difference between a shared Google Doc and a shared git repository.

A Google Doc is great when everyone is online at the same time: edits appear instantly, and the page is always the current version. But if the network drops, you cannot commit anything. If someone deletes a paragraph, you can sometimes fish it out of the version history, but that history is a secondary feature, not the main mechanism. And if you want to know *why* a sentence changed, you are usually left reading the document and guessing.

A git repository works the opposite way. Every change is a commit before it is anything else. You can work offline, review exactly what changed, see who changed it, and roll it back. The history is not an afterthought; it is the whole point.

Git-Native Agents asks: what would a multi-agent system look like if it were built that way from the start? No central scheduler, no message broker, no shared database. Just agents as repositories, messages as committed files, memories as git tags, and decisions as merge commits.

## What this is

**Git-Native Agents** is a small multi-agent orchestration system whose only coordination primitives are the ones git already provides: commits, branches, tags, merges, and the filesystem. Each agent is a separate git repository under `agents/{name}/`. Agents communicate by writing Markdown files into each other's `inbox/` directories and committing them. An agent processes its inbox with a `tick`. Long-lived facts are stored as tagged files in `memory/`. Speculative reasoning happens on **thought branches** (git branches named `thought/<topic>`), and an agent resolves that reasoning with a **merge-based decision** — literally a `git merge` that promotes the thought branch back to the agent's main line.

The result is a fleet that is auditable by default: every message, every memory, every decision leaves a permanent, signed commit trail.

## Status & capabilities

This repository contains one real, working artifact: `orchestrator.sh`, a ~265-line bash script. Every command below was traced through the source and run end-to-end before this section was written.

- ✅ **`spawn`, `send`, `tick`, `remember`, `recall`, `think`, `decide`, `broadcast`, `fleet`** — all implemented and functional. Each maps to a git operation (commit / branch / tag / merge) and leaves a commit trail.
- ✅ **Auditable by default** — every message, memory, and decision is a git commit you can inspect with `git log`, `git show`, or `git tag`.
- ✅ **Offline / local** — no server, broker, or database. Agents are plain directories with embedded git repos.
- ⚠️ **Running `fleet` on a fresh clone shows nothing** — the shipped `registry/agents.txt` contains absolute paths from another machine (`/home/phoenix/...`), and the committed `agents/*` directories are empty placeholders. To see the system work you must re-spawn agents (see Quick start), which rewrites the registry with paths valid on *your* machine.
- ⚠️ **Requires `git` on `PATH`** and a writable local filesystem. No other runtime dependency.

### What the "agent computation" actually is

This is the single most important honesty point: **there is no LLM, no model call, and no real reasoning.** A `tick` writes a fixed-format echo to `outbox/`:

```
result: processed: <the incoming message body> → computed at <unix timestamp>
```

That string is built literally in `orchestrator.sh` (`tick_agent`). So this repo gives you the *coordination plumbing* — message passing, tagged memory, thought branches, merge-based decisions — but **you must supply the intelligence yourself** by editing the `tick` logic (or calling a model from it). The shipped tick is a placeholder that proves the message round-trips.

## What this explicitly does NOT do yet

- 🔮 **No autonomous agent loop.** Agents never wake themselves. `tick` only runs when *you* invoke it; there is no scheduler, no polling, no sleep/retry loop that drives the fleet.
- 🔮 **No real reasoning / model integration.** As above, `tick` echoes; it does not think. Wiring in an LLM is left to you.
- 🔮 **No concurrency control.** No file locking, no atomic queue, no broker around git. Concurrent `send`s to the same agent repo collide on git's `index.lock` and some commits fail. Serial or low-concurrency access only.
- 🔮 **No networking or distribution.** Everything is local filesystem paths. There is no `push`/`pull` coordination between machines and no remote registry; `registry/agents.txt` is a local file of local paths.
- 🔮 **No multi-agent decision protocol.** `decide` is a single agent merging its *own* `thought/<topic>` branch. There is no voting, quorum, negotiation, or consensus across agents.
- 🔮 **No error handling on the message path.** A tick moves processed messages to `inbox/.processed-*`; there is no dead-letter queue, retry, or failure tracking. Malformed messages are best-effort parsed with `grep`/`cut`.
- 🔮 **No tests.** There is no test suite in this repository — verification is by running the orchestrator commands manually (as the Quick start does).

## Core ideas, defined

- **Agent repository**: a normal git repo at `agents/{name}/` that holds one agent's state. It contains an `AGENT.yaml` manifest, an `inbox/`, an `outbox/`, a `memory/`, and whatever thought files the agent creates.
- **Message**: a Markdown file in `inbox/` with YAML-like headers (`from`, `to`, `timestamp`, `message`). Sending a message means writing that file into the recipient's repository and committing it.
- **Tick**: one pass through an agent's inbox. The agent reads every `*.md` file, writes a response to `outbox/`, moves the original message to `inbox/.processed-*`, updates its tick counter in `AGENT.yaml`, and commits the batch.
- **Memory**: a key-value fact stored as `memory/{key}.txt` and pinned with a git tag named `memory/{key}`. Recall retrieves the tagged version with `git show`.
- **Thought branch**: a git branch named `thought/<topic>` created by the `think` command. It gives an agent a private line of history to explore an idea without disturbing its main branch. The `decide` command merges the thought branch back, turning the exploration into committed state.
- **Merge-based decision**: the act of resolving a thought branch with `git merge`. In this system a "decision" is not a vote or a distributed consensus protocol; it is the merge commit that records an agent choosing to adopt a line of reasoning.

## How it works

### Agent lifecycle

`spawn {name} {role}` creates `agents/{name}/`, runs `git init`, writes an `AGENT.yaml` manifest, creates the standard directories, commits, and registers the workspace in `registry/agents.txt`.

```
agents/{name}/
├── AGENT.yaml          # name, role, spawn time, tick count, status
├── inbox/              # incoming messages (*.md)
├── outbox/             # responses to processed messages
├── memory/             # tagged key-value storage (*.txt)
└── thought-{topic}.md  # speculative artifacts on thought branches
```

### Message protocol

`send {from} {to} {msg}` writes a file like this into the recipient's `inbox/`:

```markdown
from: architect
to: builder
timestamp: 2026-07-07T19:10:01+00:00
message: build topological-sort with 15 tests
```

The sender then commits that file in the *recipient's* repository. The commit message is truncated to 50 characters of the message body.

### Tick processing

`tick {name}` scans `inbox/*.md`. For each message it writes a response to `outbox/` with the same basename, moves the original to `inbox/.processed-*`, updates `tick:` and `status:` in `AGENT.yaml`, and commits the entire batch as one commit.

### Memory

`remember {agent} {key} {value}` writes `memory/{key}.txt`, commits, and creates or moves the tag `memory/{key}` to `HEAD`. `recall {agent} {key}` runs `git show memory/{key}:memory/{key}.txt` to retrieve the exact tagged value.

### Thought branches

`think {agent} {topic}` creates and checks out `thought/<topic>`, then writes a `thought-{topic}.md` starter file and commits it. The agent can then work on that branch — editing the thought file and committing changes — exactly as a human would on a draft branch.

`decide {agent} {topic}` checks out the agent's default branch (`main` or `master`) and merges `thought/<topic>` with the message `decide: merged <topic>`. The merge commit is the agent's decision to adopt the exploration. The thought branch itself is left in place; it can be deleted once you no longer need the draft history.

### Broadcast and fleet status

`broadcast {from} {msg}` iterates every registered agent except the sender and calls `send` once per recipient. It is `O(N)` in fleet size and produces one commit in each recipient repository.

`fleet` prints a summary table: name, role, tick count, commit count, inbox depth, memory count, and active thought branches. It reads `registry/agents.txt` to know which repositories to inspect.

### Git primitives to agent concepts

| Git primitive | Agent concept | Cost |
|---|---|---|
| `inbox/*.md` | Message queue | `O(1)` enqueue, `O(n)` scan per tick |
| `outbox/*.md` | Response queue | `O(1)` enqueue |
| `memory/*.txt` + `memory/{key}` tag | Key-value memory | `O(1)` lookup by tag |
| `thought/<topic>` branch | Speculative reasoning | `O(1)` create and merge |
| `AGENT.yaml` | Agent metadata | `O(1)` read/write |
| Git commits | Auditable state log | `O(n)` history scan |

A full round-robin of pairwise messages is `O(N²)` commits across the fleet, because every agent can send to every other agent.

## Quick start

```bash
# The shipped agents/ dir holds empty placeholder folders (and registry/agents.txt
# has paths from another machine), so 'spawn' would refuse a name that already
# exists. Clear them first on a fresh clone:
rm -rf agents/* registry/agents.txt

# Spawn a small fleet
./orchestrator.sh spawn "architect" "coordinator"
./orchestrator.sh spawn "builder" "worker"
./orchestrator.sh spawn "analyst" "analyst"

# Send a point-to-point message
./orchestrator.sh send "architect" "builder" "build topological-sort with 15 tests"

# Process the builder's inbox
./orchestrator.sh tick "builder"

# Store and recall a tagged memory
./orchestrator.sh remember "analyst" "fleet_size" "589 repos"
./orchestrator.sh recall "analyst" "fleet_size"

# Explore an idea on a thought branch, then merge it back
./orchestrator.sh think "analyst" "conservation-laws"
./orchestrator.sh decide "analyst" "conservation-laws"

# View fleet status
./orchestrator.sh fleet

# Broadcast to every other agent
./orchestrator.sh broadcast "architect" "sync: all agents report status"
```

The commands above were run against the current source before this README was written.

## API

| Command | Description |
|---|---|
| `spawn [name] [role]` | Initialize a new agent repository |
| `send [from] [to] [msg]` | Point-to-point message committed to the recipient's inbox |
| `tick [agent]` | Process every message in the agent's inbox |
| `remember [agent] [key] [value]` | Store a tagged memory |
| `recall [agent] [key]` | Retrieve a tagged memory |
| `think [agent] [topic]` | Create and check out `thought/<topic>` |
| `decide [agent] [topic]` | Merge `thought/<topic>` back to the agent's main branch |
| `fleet` | Display all registered agents' status |
| `broadcast [from] [msg]` | Send a message to every other registered agent |

## Scaling limits and concurrency

This implementation is intentionally small. It is designed for a small number of agents — think single digits to low tens — and for serial or low-concurrency access.

The current orchestrator does not use file locking, atomic queue operations, or a broker around git. If two processes send messages to the same agent repository at the same time, both may write their files successfully, but their competing `git commit` calls collide on git's `index.lock` and some commits fail. A `tick` running concurrently with a `send` to the same repository hits the same lock. Higher concurrency therefore requires either serializing access to each agent repository or adding a locking/queuing layer on top of git.

For exploration, long-running reasoning tasks, and small fleets where auditability matters more than throughput, the git-native model works well. For larger fleets or high-throughput messaging, the `O(N²)` pairwise commit overhead and the lock contention point toward a broker-based design.

## Architecture notes

Git-Native Agents extends the single-agent `git-agent-system` idea to multi-agent orchestration. Every agent is autonomous: there is no central scheduler and no shared mutable state outside the git repositories and the registry file that lists them. Coordination is implicit in which messages an agent receives, processes, and remembers.

The system pushes as much as possible onto git's own mechanics: persistence is the object database, ordering is commit history, addressing is the filesystem path, and recall is a tag lookup. The boundary is exactly where git's single-writer locking model becomes the bottleneck.

## Relationship to purplepincher/git-native-agents

This repository is the original sketch. A hardened continuation was graduated
into the [purplepincher](https://github.com/purplepincher) org as
[purplepincher/git-native-agents](https://github.com/purplepincher/git-native-agents):
it fixed the `.git/index.lock` concurrency collision described above (using
`flock` to serialize operations on shared repos) and carries a test suite
(`tests/run.sh`, `tests/concurrency.sh`) this copy does not have. If you want
to *use* the git-native coordination model rather than read its first draft,
start there. This copy stays accurate about itself: everything in
"What this explicitly does NOT do yet" above remains true of the code in
*this* repository.

## References

- Hewitt, C. "Viewing Control Structures as Patterns of Passing Messages," MIT AI Memo 410 (1976).
- Dias, V. et al. "Git as a Distributed Database," IEEE Software (2022).
- Brown, A. *The Architecture of Open Source Applications*, Vol. III: "Git." (2016).

## License

Apache-2.0
