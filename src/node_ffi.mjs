// Node.js FFI - consolidated from main_ffi, execute_cmd_ffi, cmd_utils_ffi
import { spawn, execSync } from 'child_process';

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
    return { ok: true, value: { stdout: output || '', stderr: '', status: 0 } };
  } catch (e) {
    return { ok: false, value: { ExecutionError: e.message || 'Command failed' } };
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