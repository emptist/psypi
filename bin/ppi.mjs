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

// Step 2: Spawn Pi with the generated extension
const piBin = 'pi';
const args = process.argv.slice(2);
const piArgs = ['-e', extensionPath, ...args];

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