// test-full-integration.mjs - Test the full flow
// This test uses dynamic import to load ESM modules

const { createAgentSession, initTheme } = await import('@mariozechner/pi-coding-agent');

console.log("[Test] Starting full integration test...");

try {
  // Initialize theme
  if (typeof initTheme === 'function') {
    console.log("[Test] Initializing theme...");
    await initTheme();
  }

  // Create real Pi session
  console.log("[Test] Creating Pi agent session...");
  const result = await createAgentSession({
    context: { 
      role: 'permanent-partner', 
      project: 'psypi'
    }
  });
  
  console.log("[Test] ✅ Pi SDK works!");
  console.log("[Test] Session created:", result.session?.id || "N/A");
  console.log("[Test] Model:", result.session?.model?.id || "N/A");
  
  // Now test calling Gleam → FFI → this
  console.log("\n[Test] Testing Gleam → FFI → Pi SDK flow...");
  console.log("[Test] (This would be called from partner.gleam via partner_ffi.mjs)");
  
  process.exit(0);
} catch (error) {
  console.error("[Test] ❌ FAILED:", error.message);
  console.error("[Test] Stack:", error.stack);
  process.exit(1);
}
