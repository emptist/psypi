import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export function spawn_pi(args) {
  const psypiRoot = path.resolve(__dirname, '../../../../..');
  const piPath = 'pi'; // Assume pi is in PATH
  
  const child = spawn(piPath, args, {
    stdio: 'inherit',
    cwd: psypiRoot,
    env: { ...process.env, PSYPI_ROOT: psypiRoot }
  });
  
  child.on('error', (err) => {
    console.error('Failed to spawn Pi:', err.message);
  });
}
