#!/usr/bin/env node
// cli-wrapper.ts - Launch Pi TUI with psypi extension
// psypi = Pi TUI + psypi extension (not a standalone CLI!)
// Small + Pure = Resilience!

import { spawn } from 'child_process';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Path to the compiled psypi extension
const extensionPath = resolve(__dirname, 'agent/extension/extension.js');

// Launch Pi with the psypi extension
// When no args: launches Pi TUI with extension loaded
// When args provided: passes them to Pi (e.g., for Pi's CLI mode)
const piArgs = ['-e', extensionPath, ...process.argv.slice(2)];

const pi = spawn('pi', piArgs, {
    stdio: 'inherit', // Pi takes over the terminal
    shell: false
});

pi.on('close', (code) => {
    process.exit(code || 0);
});

pi.on('error', (err) => {
    console.error('Failed to launch Pi:', err.message);
    console.error('Make sure pi is installed: npm install -g @mariozechner/pi-coding-agent');
    process.exit(1);
});
