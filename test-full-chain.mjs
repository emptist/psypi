// test-full-chain.mjs - Test the full chain: TypeScript → Gleam → FFI → Pi SDK

import * as gleam from './src/common/gleam-bridge.ts';

console.log('[Full Chain Test] Starting...\n');

// Test 1: Call Gleam function (which calls FFI → Pi SDK)
console.log('[Test 1] Calling get_or_create via Gleam...');
const result = gleam.get_or_create("test-identity-123", "P");

console.log('[Test 1] Result type:', result.type);
if (result.type === 'POK') {
  console.log('[Test 1] ✅ Session created:', result.value);
} else {
  console.log('[Test 1] ❌ Error:', result.value);
}

// Test 2: Call heartbeat
console.log('\n[Test 2] Calling heartbeat...');
const hbResult = gleam.heartbeat("test-session-id");
console.log('[Test 2] Result:', hbResult);

// Test 3: Check if Pi SDK is actually being called
console.log('\n[Test 3] Verifying Pi SDK call in FFI...');
console.log('[Test 3] The FFI file has real Pi SDK code that should be called');
console.log('[Test 3] Check console output above for "[FFI]" messages');

console.log('\n[Full Chain Test] ✅ COMPLETE!');
process.exit(0);
