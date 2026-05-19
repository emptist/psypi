// Self-patch script — run this inside Pi to fix the FFI without restarting
// Usage: node patch_ffi.mjs

import { readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ffiPath = join(__dirname, 'build/dev/javascript/psypi/pi_extension_ffi.mjs');

// Read current content
const current = readFileSync(ffiPath, 'utf-8');

// Check if already patched
if (current.includes('callMonitor exception:')) {
  console.log('FFI already patched');
  process.exit(0);
}

console.log('Patching pi_extension_ffi.mjs...');

// Replace the old catch block in call_monitor
const patched = current.replace(
  /catch \(e\) \{\s*return \{ ok: false, value: e\.message \|\| 'callMonitor failed' \};\s*\}/,
  `catch (e) {
    const msg = (e && e.message) ? String(e.message) : (e ? String(e) : 'callMonitor: unknown error (error object had no message)');
    return { ok: false, value: 'callMonitor exception: ' + msg };
  }`
);

writeFileSync(ffiPath, patched, 'utf-8');
console.log('Patched! Restart Pi TUI to pick up changes.');
