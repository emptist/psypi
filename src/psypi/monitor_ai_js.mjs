// JavaScript interop for monitor_ai.gleam
import { createRequire } from 'module';
const require = createRequire(import.meta.url);

import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Get free disk space in GB
export function get_disk_free_gb() {
  try {
    const output = execSync('df -k / | tail -1 | awk \'{print $4}\'').toString().trim();
    const kbFree = parseInt(output, 10);
    if (isNaN(kbFree)) return 0.0;
    // Convert KB to GB
    return kbFree / (1024 * 1024);
  } catch (e) {
    console.error('Error getting disk space:', e.message);
    return 0.0;
  }
}

// Get build status
export function get_build_status() {
  try {
    // From: /Users/jk/gits/hub/tools_ai/psypi/gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli
    // Go up 7 levels to: /Users/jk/gits/hub/tools_ai/psypi
    const projectRoot = path.resolve(__dirname, '../../../../../../..');
    const buildDir = path.join(projectRoot, 'gleam/psypi_core/build/dev/javascript/psypi_core');
    if (fs.existsSync(buildDir)) {
      const files = fs.readdirSync(buildDir);
      if (files.length > 0) {
        return "built";
      }
    }
    return "not_built";
  } catch (e) {
    console.error('Error checking build status:', e.message);
    return "unknown";
  }
}

// Get current timestamp
export function get_timestamp() {
  return new Date().toISOString();
}
