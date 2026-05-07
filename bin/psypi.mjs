// Wrapper to run Gleam-compiled executable
import { main } from '../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/main.mjs';

const args = process.argv.slice(2);

// main returns Promise<Int>
const result = main(args);

if (result && typeof result.then === 'function') {
  result.then((code) => {
    process.exit(code || 0);
  }).catch((err) => {
    console.error('Error:', err.message);
    process.exit(1);
  });
} else {
  // Should not happen
  console.log(result);
  process.exit(0);
}
