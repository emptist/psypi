#!/usr/bin/env node
import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';
import { writeFileSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(resolve(__filename));
const projectDir = resolve(__dirname, '..');

const args = process.argv.slice(2);
const minimal = args.includes('--minimal');

if (minimal) {
  process.env.PPI_MINIMAL = 'true';
  args.splice(args.indexOf('--minimal'), 1);
}

const { generate } = await import(
  join(projectDir, 'build/dev/javascript/psypi/extension_generator.mjs')
);

const extensionPath = join(projectDir, 'extension.js');
writeFileSync(extensionPath, generate(), 'utf8');

const piArgs = minimal
  ? ['--no-session', '--no-skills', '--no-context-files',
     '--tools', 'read,bash,psypi-somatic-id,psypi-autonomic-id',
     '-e', extensionPath, ...args]
  : ['-e', extensionPath, ...args];

const child = spawn('pi', piArgs, {
  stdio: 'inherit',
  shell: false,
  cwd: projectDir
});

child.on('close', code => process.exit(code || 0));
child.on('error', err => {
  console.error('Failed to start Pi:', err.message);
  process.exit(1);
});