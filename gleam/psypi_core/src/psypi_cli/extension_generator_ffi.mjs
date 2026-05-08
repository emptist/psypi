// FFI helper for extension_generator.gleam
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Get the project root (where psypi lives)
// When run via `gleam run`, cwd is the gleam/ dir, so go up to project root
export function get_project_root() {
  // __dirname is build/dev/javascript/psypi_cli/
  // Go up 4 levels: psypi_cli → psypi_core → javascript → dev → build → gleam → psypi
  // Actually, use PSYPI_ROOT env var if set, otherwise compute from cwd
  if (process.env.PSYPI_ROOT) {
    return process.env.PSYPI_ROOT;
  }
  // From build/dev/javascript/psypi_cli/, go up to project root
  // psypi_cli → psypi_core → javascript → dev → build → gleam → psypi = 6 levels
  return path.resolve(__dirname, '../../../../../../..');
}
