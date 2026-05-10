#!/bin/bash
# Setup git hooks - run this after clone/pull

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$GIT_ROOT" ]; then
    echo "Not a git repository"
    exit 1
fi

echo "Setting up git hooks..."

# Symlink prepare-commit-msg hook
if [ -f "$GIT_ROOT/hooks/prepare-commit-msg" ]; then
    ln -sf "$GIT_ROOT/hooks/prepare-commit-msg" "$GIT_ROOT/.git/hooks/prepare-commit-msg"
    echo "✅ Installed prepare-commit-msg hook"
else
    echo "❌ Hook file not found: $GIT_ROOT/hooks/prepare-commit-msg"
    exit 1
fi

echo "Done! Hooks are now active."
