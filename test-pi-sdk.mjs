// test-pi-sdk.mjs - Final verification
import { createAgentSession, initTheme } from "@mariozechner/pi-coding-agent";

console.log("[Test] Starting Pi SDK verification...");

try {
  // Initialize theme first
  if (typeof initTheme === 'function') {
    console.log("[Test] Calling initTheme()...");
    await initTheme();
  }

  const result = await createAgentSession({
    context: { role: 'test', project: 'psypi' }
  });
  
  console.log("[Test] ✅ Pi SDK works!");
  console.log("[Test] Session ID:", result.session?.id || "N/A");
  console.log("[Test] Model:", result.session?.model?.id || "N/A");
  
  process.exit(0);
} catch (error) {
  console.error("[Test] ❌ Pi SDK failed:", error.message);
  process.exit(1);
}
