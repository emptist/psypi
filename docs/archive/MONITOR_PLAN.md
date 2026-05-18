# Monitor Implementation Plan

## Goal
Implement Monitor for psypi - local LLM consultant + silent safety hooks.

## Status: In Progress

## Plan (Priority Order)

### Phase 1: Core Infrastructure ✅ DONE
- [x] Research Pi events from extensions.md
- [x] Add event hooks: session_start, agent_start, agent_end, tool_result
- [x] Regenerate extension.js (6 hooks total)
- [x] Create Monitor skill (.pi/skills/monitor/SKILL.md)

### Phase 2: Safety Hooks 🔄 IN PROGRESS
- [ ] Implement tool_call hook that can BLOCK dangerous operations
- [ ] Define what operations are "dangerous" (spawn, delete, etc.)

### Phase 3: Consultation Tool
- [ ] Test psypi-autonomic-consult tool in Pi
- [ ] Verify it calls LLM via ctx.model
- [ ] Handle edge cases (timeout, model unavailable)

### Phase 4: Guidance Injection
- [ ] Add before_agent_start hook
- [ ] Inject Monitor guidance into agent context
- [ ] Track agent decisions for post-session review

### Phase 5: Documentation
- [ ] Document how agentbot uses Monitor
- [ ] List all Monitor tools
- [ ] Explain event hooks integration

## Key Decisions
- Monitor uses agentbot's model via ctx.model
- LLM call in JS wrapper (ctx available only in execute)
- Two modes: Silent (safety) + Communication (tool + skill)
- Event-driven, NOT periodic

## Completed Decisions
- 4 event hooks added to extension_generator.gleam
- extension.js regenerated with 6 pi.on() hooks
- Pi Events reference saved to docs/archive/PI_EVENTS_REFERENCE.md

## Blockers
- None

## Reference
- Full Pi events: docs/archive/PI_EVENTS_REFERENCE.md
- Session summary: docs/archive/SESSION_SUMMARY_2026-05-10.md