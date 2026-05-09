#!/usr/bin/env node
// psypi entry point: generate extension.js from Gleam, then spawn Pi

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { writeFileSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Import the compiled Gleam generator
const { generate } = await import(
  join(__dirname, '../build/dev/javascript/psypi/psypi/extension_generator.mjs')
);

// Path to extension.js
const extensionPath = join(__dirname, '../src/agent/extension/extension.js');

// Step 1: Generate extension.js from Gleam PiToolCall values
const content = generate();
writeFileSync(extensionPath, content, 'utf8');

// Step 2: Spawn Pi with the generated extension
const piBin = 'pi';
const args = process.argv.slice(2);
const piArgs = ['-e', extensionPath, ...args];

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
