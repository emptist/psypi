# Monitor - 3 Modes of Operation

```
                    ┌─────────────────────────────────────────┐
                    │              MONITOR                    │
                    │  (single brain, 3 modes)               │
                    └─────────────────────────────────────────┘
                                        ↑
         ┌──────────────────────────────┴───────────────────────────────┐
         │                                                            │
    ╔════╪═══════════╗                            ╔═══════════════════╪═══╗
    ║ 1. SILENT      ║                            ║ 3. END OF WORKFLOW ║
    ║ (always on)    ║                            ║ (e.g. git commit)  ║
    ║                ║                            ║                    ║
    ║ - health       ║                            ║ inter_review →    ║
    ║ - skills       ║                            ║ Monitor LLM       ║
    ║ - cleanup      ║                            ║ → score/feedback  ║
    ║ - learning     ║                            ║ → pass/fail       ║
    ║ - git tracing  ║                            ║ → git commit      ║
    ║ - memory       ║                            ╚════════════════════╝
    ║ - docs update  ║
    ╚════════════════╝
                                        ↑
                                        │
         ┌──────────────────────────────┴────────────┐
         │ 2. MIDDLE OF WORKFLOW (proactive)        │
         │                                          │
         │ Worker: "Should I use array or dict?"   │
         │ Worker: "What do you think?"            │
         │ psypi-monitor-consult → Monitor          │
         └──────────────────────────────────────────┘
```

## Mode 1: Silent (always running)
Monitor watches and maintains the system:
- Health monitoring (DB, memory, disk)
- Skill discovery and loading for current project
- Database cleanup (old sessions, stale data)
- Auto-update documentation
- Learning from worker actions
- Git operation tracing (detect odd patterns)
- Memory tracking on bash events

## Mode 2: Middle of Workflow (proactive)
Worker proactively consults Monitor:
- "Should I use array or dict?"
- "What do you think about this approach?"
- Tool: `psypi-monitor-consult`

## Mode 3: End of Workflow (triggered)
Triggered at workflow boundaries (e.g., git commit):
- inter_review uses Monitor's LLM
- Returns score/feedback
- Decides pass/fail
- Then proceeds to git commit

---

## Current State (needs fixing)
- Mode 1: ✅ Implemented (event hooks)
- Mode 2: ✅ Implemented (psypi-monitor-consult)
- Mode 3: ❌ Still uses external LLM (P-tencent/hy3-preview:free-psypi)

**Fix needed:** inter_review should use Monitor's LLM, not external service.