#!/usr/bin/env node
// ppi entry point: generate extension.js from Gleam, then spawn Pi

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';
import { writeFileSync, realpathSync } from 'fs';

// Resolve the project directory (parent of bin/, following symlinks)
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(realpathSync(__filename));
const projectDir = resolve(__dirname, '..');

// Import the compiled Gleam generator from the project's build directory
const { generate } = await import(
  join(projectDir, 'build/dev/javascript/psypi/extension_generator.mjs')
);

// Path to extension.js (in the project directory)
const extensionPath = join(projectDir, 'extension.js');

// Step 1: Generate extension.js from Gleam PiToolCall values
const content = generate();
writeFileSync(extensionPath, content, 'utf8');

// Step 2: Handle special CLI commands before spawning Pi
const piBin = 'pi';
let args = process.argv.slice(2);
let minimal = false;

// Special case: `psypi commit <message>` — direct commit with review, no TUI
if (args[0] === 'commit') {
  const commitMessage = args.slice(1).join(' ');
  if (!commitMessage.trim()) {
    console.error('Usage: psypi commit <message>');
    process.exit(1);
  }
  const { execSync } = await import('child_process');
  try {
    // Check for uncommitted changes
    const status = execSync('git status --porcelain', { encoding: 'utf8' });
    if (!status.trim()) {
      console.log('Nothing to commit.');
      process.exit(0);
    }
    // Stage and commit
    execSync('git add -A', { encoding: 'utf8' });
    execSync('git commit -m ' + JSON.stringify(commitMessage), { encoding: 'utf8' });
    console.log('✅ Committed: ' + commitMessage);
    process.exit(0);
  } catch (e) {
    console.error('Commit failed: ' + e.message);
    process.exit(1);
  }
}
if (args.includes('--minimal')) {
  minimal = true;
  args = args.filter((a) => a !== '--minimal');
  // Persist minimal mode in user settings
  const { homedir } = await import('os');
  const { join, dirname } = await import('path');
  const { readFileSync, writeFileSync, mkdirSync } = await import('fs');
  const settingsDir = join(homedir(), '.pi', 'agent');
  const settingsPath = join(settingsDir, 'settings.json');
  try { mkdirSync(settingsDir, { recursive: true }); } catch (_) { }
  let settings = {};
  try { settings = JSON.parse(readFileSync(settingsPath, 'utf8')); } catch (_) { }
  settings.psypiMode = 'minimal';
  writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf8');
} else {
  // Ensure normal mode is set when not minimal
  const { homedir } = await import('os');
  const { join, dirname } = await import('path');
  const { readFileSync, writeFileSync, mkdirSync } = await import('fs');
  const settingsPath = join(homedir(), '.pi', 'agent', 'settings.json');
  try { mkdirSync(dirname(settingsPath), { recursive: true }); } catch (_) { }
  let settings = {};
  try { settings = JSON.parse(readFileSync(settingsPath, 'utf8')); } catch (_) { }
  settings.psypiMode = 'normal';
  writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf8');
}

// Step 3: Build pi arguments
const piArgs = ['-e', extensionPath, ...args];

// Step 4: Handle minimal mode - optimized flags for low-context models
if (minimal) {
  // --no-skills: skip loading skills from ~/.agents/skills/ and .pi/skills/
  // --no-session: ephemeral session, no history loaded (prevents n_keep overflow)
  // --no-context-files: skip loading AGENTS.md, CLAUDE.md (reduces prompt size)
  // --tools read,bash: minimal toolset (reduces tool descriptions in prompt)
  piArgs.unshift('--no-session', '--no-skills', '--no-context-files', '--tools', 'read,bash,psypi-somatic-id,psypi-autonomic-id');
  console.error('[psypi] Minimal mode: skills=off, context-files=off, tools=read,bash, ephemeral session');
}

const child = spawn(piBin, piArgs, {
  stdio: 'inherit',
  shell: false,
  cwd: process.cwd()
});

child.on('close', (code) => {
  process.exit(code || 0);
});

child.on('error', (err) => {
  console.error('Failed to start Pi:', err.message);
  process.exit(1);
});