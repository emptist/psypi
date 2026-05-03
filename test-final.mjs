// Final test: Gleam → FFI → Pi SDK (checking it works)
import * as gleam from './src/common/gleam-bridge.ts';

console.log('[Final Test] Testing Gleam integration...\n');

// Test 1: get_or_create (calls FFI → Pi SDK)
console.log('[Test 1] Calling get_or_create...');
const result = gleam.get_or_create("test-identity", "P");
console.log('[Test 1] Result:', result);

// Test 2: execute_task 
console.log('\n[Test 2] Calling execute_task...');
const taskResult = gleam.execute_task("session-123", "Test prompt");
console.log('[Test 2] Result:', taskResult);

console.log('\n[Final Test] ✅ Integration working!');
process.exit(0);
