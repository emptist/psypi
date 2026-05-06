// FFI helper for main.gleam - spawn Pi TUI
import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export function spawn_pi(args) {
  // Spawn Pi TUI with given arguments
  const piProcess = spawn('pi', args, {
    stdio: 'inherit',
    cwd: process.env.PSYPI_ROOT || process.cwd(),
    env: process.env
  });
  
  return new Promise((resolve, reject) => {
    piProcess.on('close', (code) => {
      resolve(code);
    });
    piProcess.on('error', (err) => {
      reject(err);
    });
  });
}
