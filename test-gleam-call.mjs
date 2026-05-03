// Test calling Gleam function via bridge
import * as gleam from './src/common/gleam-bridge.ts';

console.log('[Test] Calling Gleam function get_or_create...');

// Call the Gleam function
const result = gleam.get_or_create("test-identity-123", "P");

console.log('[Test] Result:', result);
console.log('[Test] Result type:', result ? (result.type || 'unknown') : 'null');

process.exit(0);
