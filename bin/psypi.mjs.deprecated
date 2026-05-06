// Simple wrapper to run Gleam CLI
import { main } from '../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/main.mjs';

const args = process.argv.slice(2);
const gleamArgs = args;

const result = main(gleamArgs);

if (result && typeof result.then === 'function') {
  result.then((output) => {
    if (output) console.log(output);
    process.exit(0);
  }).catch((err) => {
    console.error('Error:', err.message);
    process.exit(1);
  });
} else {
  if (result) console.log(result);
  process.exit(0);
}
