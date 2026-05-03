# Gleam Documentation for psypi

This directory contains documentation for Gleam integration in psypi.

## Files

- **GLEAM_INTEGRATION.md** - Integration guide for using Gleam with TypeScript in psypi
- **README.md** (this file) - Overview of documentation

## Quick Links

### Official Gleam Resources
- [Gleam Website](https://gleam.run/)
- [Gleam Documentation](https://gleam.run/documentation/)
- [Gleam JS Target](https://gleam.run/targets/javascript/)
- [Gleam Language Server](https://gleam.run/getting-started/editor-support/)

### Reference Projects
- **Gleam repo**: `../refers/gleam/` - Official Gleam compiler and tools
- **traenupi**: `../traenupi/gleam/traenupi_core/` - Working example with 18+ modules
- **Trae AI's blog**: `../traenupi/gleam/traenupi_core/BLOG_POST.md` - Comprehensive migration guide

## Getting Started

1. Read `GLEAM_INTEGRATION.md` for setup instructions
2. Check the Gleam repo at `../refers/gleam/` for editor support (LSP)
3. See `gleam/psypi_core/` for the actual Gleam modules

## Editor Setup

Gleam includes a built-in language server:
```bash
gleam lsp  # Start the language server
```

Configure your editor to use `gleam lsp` for Gleam files.
