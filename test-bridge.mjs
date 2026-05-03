// Quick test to verify Gleam bridge imports work
import * as gleam from './src/common/gleam-bridge.ts';

console.log('[Test] Testing Gleam bridge imports...');
console.log('[Test] Available exports:', Object.keys(gleam));

// Test if functions exist
if (gleam.get_or_create) {
  console.log('[Test] ✅ get_or_create function exists');
} else {
  console.log('[Test] ❌ get_or_create not found');
}

if (gleam.create_pi_session) {
  console.log('[Test] ✅ create_pi_session function exists (with Pi SDK!)');
} else {
  console.log('[Test] ❌ create_pi_session not found');
}
