# Psypi - Unified AI Coordination System

> **Psy**che + **Pi** = Unified AI coordination system  
> Merging Nezha kernel + NuPI agent into one maintainable project.

## Vision

- **Replace** both `nezha` and `nupi` as the global CLI
- **Unified** codebase (no more maintaining two projects)
- **Simple** integration (no server, no strange things)
- **Kernel + Agent** in one package

## Architecture

```
psypi/
├── src/
│   ├── cli.ts          # Unified CLI (commander)
│   ├── kernel/         # Nezha core (DB, tasks, memory, skills)
│   ├── agent/          # NuPI core (Pi extension, autonomous work)
│   └── shared/         # Shared types/interfaces
├── scripts/            # Build/release scripts
└── dist/              # Compiled output
```

## Commands (Planned)

### Kernel (from Nezha)
- `psypi task-add` - Add a task
- `psypi tasks` - List tasks
- `psypi issue-add` - Add an issue
- `psypi issues` - List issues
- `psypi skill-*` - Skill management
- `psypi reflect` - All-in-one reflection

### Agent (from NuPI)
- `psypi session-start` - Start agent session
- `psypi session-end` - End agent session
- `psypi autonomous` - Autonomous work mode

## Development

```bash
# Install dependencies
npm install

# Build
npm run build

# Development mode
npm run dev

# Type check
npm run typecheck
```

## Migration Path

1. **Phase 1**: Scaffolding (this version)
2. **Phase 2**: Integrate Nezha kernel
3. **Phase 3**: Integrate NuPI agent
4. **Phase 4**: Replace nezha/nupi globally
5. **Phase 5**: Deprecate nezha/nupi

## Status

🚧 **Under active development** - First working version soon!

---

**Note**: Piano project has been deleted (failure). Psypi is the future.
