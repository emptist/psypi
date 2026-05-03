// test-integration.mjs - Test Gleam → FFI → Pi SDK
import { get_or_create } from './gleam/psypi_core/build/dev/javascript/psypi_core/partner.mjs';

console.log("[Integration Test] Starting...");

try {
  // Call Gleam function (which calls FFI → Pi SDK)
  const result = await get_or_create("P-tencent/hy3-preview:free-psypi", "P");
  
  console.log("[Integration Test] Result:", result);
  console.log("[Integration Test] Type:", result.type);
  
  if (result.type === 'POK') {
    console.log("[Integration Test] ✅ SUCCESS! Session ID:", result.value);
  } else {
    console.log("[Integration Test] ⚠️ Result:", result.value);
  }
  
  process.exit(0);
} catch (error) {
  console.error("[Integration Test] ❌ FAILED:", error.message);
  process.exit(1);
}
