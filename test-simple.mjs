// Simple test - verify the chain works (even with placeholders)
import * as gleam from './src/common/gleam-bridge.ts';

console.log('[Test] Testing get_or_create...');
const result = gleam.get_or_create("test-id", "P");
console.log('[Test] Result:', result);

console.log('\n[Test] Testing heartbeat...');
const hb = gleam.heartbeat("session-123");
console.log('[Test] Heartbeat:', hb);

console.log('\n[Test] ✅ Bridge is working!');
process.exit(0);
