# Gleam Integration for psypi

This directory contains Gleam modules for psypi's core functionality.

## Structure

```
gleam/
├── psypi_core/           # Gleam project (compiles to JavaScript)
│   ├── src/              # Gleam source files
│   ├── test/             # Gleam tests
│   ├── gleam.toml        # Gleam configuration
│   └── README.md         # Gleam project docs
├── docs/                 # Documentation
│   ├── README.md         # Documentation overview
│   └── GLEAM_INTEGRATION.md  # Integration guide
└── README.md             # This file
```

## Quick Start

1. **Build Gleam modules**: `cd gleam/psypi_core && gleam build`
2. **Run tests**: `cd gleam/psypi_core && gleam test`
3. **Use in TypeScript**: Import from `gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core.mjs`
4. **Documentation**: See `gleam/docs/` for integration guides

## Documentation

- `gleam/docs/GLEAM_INTEGRATION.md` - TypeScript integration guide
- `gleam/docs/README.md` - Documentation overview
- Official docs: https://gleam.run/

## Why Gleam?

- **Type safety**: ML-style type system with pattern matching
- **Immutable by default**: All data structures are immutable
- **Compiles to JS**: Seamless integration with TypeScript projects
- **Generates .d.ts**: TypeScript declarations auto-generated
- **Built-in LSP**: `gleam lsp` for editor support

## Editor Setup

Gleam includes a built-in language server:
```bash
gleam lsp  # Start the language server
```

Configure your editor to use `gleam lsp` for `.gleam` files.

## Resources

- **Official**: https://gleam.run/
- **JS Target**: https://gleam.run/targets/javascript/
- **Reference repo**: `../refers/gleam/` (official Gleam compiler)
- **Working example**: `../traenupi/gleam/traenupi_core/` (18+ modules)
- **Migration guide**: `../traenupi/gleam/traenupi_core/BLOG_POST.md` (Trae AI's blog)
