// cli-wrapper.ts - Thin wrapper to run Gleam CLI
// This replaces the old cli.ts (1358 lines → 20 lines!)
// Small + Pure = Resilience!

import { createRequire } from 'module';
import { resolve } from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const __dirname = fileURLToPath(new URL('.', import.meta.url));

// Import and run the Gleam CLI
const gleamCliPath = resolve(
  __dirname,
  '../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/main.mjs'
);

try {
  // The Gleam CLI exports a main function
  const { main } = await import(gleamCliPath);
  
  // Get command line args (skip node and script path)
  const args = process.argv.slice(2);
  
  // Convert args to Gleam List
  const gleamArgs = Array.isArray(args) ? args : [];
  
  // Run the Gleam CLI
  const result = main(gleamArgs);
  
  // Handle promise result
  if (result && typeof result.then === 'function') {
    result.then((output: string) => {
      if (output) console.log(output);
      process.exit(0);
    }).catch((err: Error) => {
      console.error('Gleam CLI error:', err.message);
      process.exit(1);
    });
  } else {
    if (result) console.log(result);
    process.exit(0);
  }
} catch (err) {
  console.error('Failed to load Gleam CLI:', err);
  process.exit(1);
}
