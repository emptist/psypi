#!/usr/bin/env node
// Wrapper to run Gleam-compiled executable WITH Pi extension!

// FIX: Load psypi extension automatically so Pi tools work anywhere!

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Path to extension.js
const extensionPath = join(__dirname, '../src/agent/extension/extension.js');

// Path to pi binary
const piBin = 'pi';

// Build arguments: load extension + pass through user args
const args = process.argv.slice(2);
const piArgs = ['-e', extensionPath, ...args];

// Spawn Pi with extension loaded
const child = spawn(piBin, piArgs, {
  stdio: 'inherit',
  shell: false
});

child.on('close', (code) => {
  process.exit(code || 0);
});

child.on('error', (err) => {
  console.error('Failed to start Pi:', err.message);
  process.exit(1);
});
