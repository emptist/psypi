// Node.js FFI - consolidated from main_ffi, execute_cmd_ffi, cmd_utils_ffi
import { spawn, execSync } from 'child_process';
import { Ok, Error } from './gleam.mjs';

// Get project root (for extension_generator.gleam)
export function get_project_root() {
  return process.cwd();
}

// Spawn Pi process
export function spawn_pi(args) {
  const piProcess = spawn('pi', args, {
    stdio: 'inherit',
    cwd: process.cwd(),
    env: process.env
  });
  return new Promise((resolve, reject) => {
    piProcess.on('close', (code) => resolve(code));
    piProcess.on('error', (err) => reject(err));
  });
}

// Execute command with timeout (default 30s)
export function execute(cmd, timeout = 30000) {
  try {
    const output = execSync(cmd, {
      encoding: 'utf-8',
      timeout: timeout,
      stdio: ['pipe', 'pipe', 'pipe']
    });
    return new Ok({ stdout: output || '', stderr: '', status: 0 });
  } catch (e) {
    return new Error({ ExecutionError: e.message || 'Command failed' });
  }
}

// Check if command exists
export function exists(cmd) {
  try {
    execSync('which ' + cmd, { stdio: 'ignore' });
    return true;
  } catch (e) {
    return false;
  }
}

// Get environment variable
export function get_env(name) {
  return process.env[name] || '';
}

// Get project ID for RLS policies (PSYPI_PROJECT_ID env var, or empty string for default)
export function get_project_id_env() {
  return process.env['PSYPI_PROJECT_ID'] || '';
}

// Ensure directory exists
export function ensure_dir(path) {
  const fs = require('fs');
  fs.mkdirSync(path, { recursive: true });
}

// Write text file
export function write_text_file(path, content) {
  const fs = require('fs');
  fs.writeFileSync(path, content, 'utf8');
}

// Current time in milliseconds
export function now_ms() {
  return new Ok(Date.now());
}