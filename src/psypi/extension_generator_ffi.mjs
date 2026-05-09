// FFI helper for extension_generator.gleam
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Get the project root (where psypi lives)
// When run via `gleam run`, cwd is the gleam/ dir, so go up to project root
export function get_project_root() {
  if (process.env.PSYPI_ROOT) {
    return process.env.PSYPI_ROOT;
  }
  return path.resolve(__dirname, '../../..');
}


