---
description: Guide for using pnpm package manager in psypi project
---

# pnpm Standard Usage Guide

## Overview
pnpm is a fast, disk space efficient package manager for Node.js. It uses a content-addressable storage to save files and symlinks them to your projects.

## Installation
```bash
# Install pnpm globally
npm install -g pnpm

# Or via homebrew (macOS)
brew install pnpm

# Or via corepack (recommended)
corepack enable
corepack prepare pnpm@latest --activate
```

## Essential Commands

### Installing Dependencies

```bash
# Install all dependencies from package.json
pnpm install

# Short form
pnpm i

# Install in production mode only (no devDependencies)
pnpm install --prod

# Install a new dependency
pnpm add <package>
pnpm add lodash

# Install a dev dependency
pnpm add -D <package>
pnpm add -D typescript

# Install a global package
pnpm add -g <package>

# Install from a specific registry
pnpm add <package> --registry <url>
```

### Removing Dependencies

```bash
# Remove a dependency
pnpm remove <package>
pnpm rm lodash

# Remove a dev dependency
pnpm remove -D <package>
```

### Running Scripts

```bash
# Run a script defined in package.json
pnpm run <script>
pnpm run build
pnpm run test

# Short form (for non-standard script names)
pnpm <script>
pnpm build
pnpm test

# Run with additional arguments
pnpm run build -- --watch
```

### Building Projects

```bash
# Standard build (if "build" script exists in package.json)
pnpm build

# Or explicitly:
pnpm run build

# Common build-related scripts:
pnpm run clean      # Clean build artifacts
pnpm run build:prod # Production build
pnpm run build:dev  # Development build
```

### Updating Dependencies

```bash
# Update all dependencies
pnpm update

# Update a specific package
pnpm update <package>

# Update to latest versions (ignoring version ranges in package.json)
pnpm update --latest
```

### Other Useful Commands

```bash
# List installed packages
pnpm list
pnpm ls

# List with dependencies
pnpm list --depth=1

# Check for outdated packages
pnpm outdated

# Run interactive dependency update UI
pnpm dlx npm-check --update

# Execute a command temporarily using a package
pnpm dlx <package>
pnpm dlx create-react-app my-app

# Link local packages (monorepo)
pnpm link <package>

# Filter commands in monorepos
pnpm --filter <package-name> <command>
pnpm --filter @myapp/web build
```

## pnpm-Specific Features

### Workspace (Monorepo) Commands

```bash
# Initialize workspace
pnpm init

# Add dependency to specific workspace package
pnpm --filter <package-name> add <dependency>

# Run script in all workspace packages
pnpm -r run build

# Run script in workspace packages that changed since master
pnpm -r --changed since=master run build
```

### Lockfile

```bash
# pnpm uses pnpm-lock.yaml (similar to package-lock.json or yarn.lock)
# Regenerate lockfile
pnpm install --no-frozen-lockfile

# Use frozen lockfile (CI environments)
pnpm install --frozen-lockfile
```

## Common Workflows

### New Project Setup
```bash
# 1. Initialize project
pnpm init

# 2. Add dependencies
pnpm add react react-dom
pnpm add -D typescript @types/react

# 3. Install everything
pnpm install

# 4. Build
pnpm build

# 5. Start development
pnpm dev
```

### CI/CD Build
```bash
# Install with frozen lockfile (fail if lockfile is outdated)
pnpm install --frozen-lockfile

# Build
pnpm build

# Test
pnpm test
```

## Tips

1. **Faster installs**: pnpm is generally faster than npm/yarn due to its unique node_modules structure
2. **Disk efficiency**: Shared dependencies are stored once on disk and symlinked
3. **Strictness**: pnpm enforces that packages can only access dependencies they declare
4. **Node version**: Use `pnpm env` to manage Node.js versions
5. **Audit**: Run `pnpm audit` to check for security vulnerabilities

## Troubleshooting

```bash
# Clear cache
pnpm store prune

# Reinstall from scratch
rm -rf node_modules pnpm-lock.yaml
pnpm install

# Check pnpm version
pnpm -v

# Get help for a command
pnpm <command> --help
```
