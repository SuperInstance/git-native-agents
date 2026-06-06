# git-native-agents

Multi-agent orchestration system built entirely on git primitives. Agents communicate through each other's git repositories.

## Architecture

```
orchestrator.sh
├── agents/
│   ├── architect/     (coordinator)  — dispatches work
│   ├── builder/       (worker)       — builds code
│   ├── analyst/       (analyst)      — analyzes patterns
│   ├── memory-keeper/ (librarian)    — stores knowledge
│   └── scout/         (explorer)     — finds opportunities
└── registry/
    └── agents.txt     — fleet membership
```

## Agent Communication

Agents send messages by writing to each other's `inbox/` directories:

```bash
# Point-to-point
./orchestrator.sh send "architect" "builder" "build topological-sort with 15 tests"

# Broadcast
./orchestrator.sh broadcast "architect" "sync: all agents report status"
```

## Usage

```bash
# Spawn agents with roles
./orchestrator.sh spawn "architect" "coordinator"
./orchestrator.sh spawn "builder" "worker"
./orchestrator.sh spawn "analyst" "analyst"
./orchestrator.sh spawn "memory-keeper" "librarian"
./orchestrator.sh spawn "scout" "explorer"

# Send messages
./orchestrator.sh send "architect" "builder" "build the next crate"

# Process inbox (agent tick)
./orchestrator.sh tick "builder"

# Store memories (git tags)
./orchestrator.sh remember "memory-keeper" "fleet_size" "589 repos"

# Recall memories
./orchestrator.sh recall "memory-keeper" "fleet_size"

# Create thought branches
./orchestrator.sh think "analyst" "conservation-laws"

# View fleet status
./orchestrator.sh fleet
```

## Primitives

| Git Primitive | Agent Concept |
|---------------|---------------|
| `inbox/*.md` | Message queue |
| `outbox/*.md` | Response queue |
| `memory/*.txt` + git tags | Key-value memory |
| `thought/*` branches | Parallel exploration |
| `AGENT.yaml` | Agent metadata |
| Git commits | Auditable state log |

## When to Use

- **Good for**: 5-50 agents, long-running reasoning, audit trail matters
- **Not for**: Real-time systems, 1000+ agents, low-latency requirements

## License

MIT
