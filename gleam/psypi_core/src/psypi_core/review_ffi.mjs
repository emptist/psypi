// gleam/psypi_core/src/psypi_core/review_ffi.mjs
// FFI bridge for review.gleam - RETURNS PLAIN STRINGS!

import { createAgentSession, initTheme } from "@mariozechner/pi-coding-agent";

// FFI: Run review (returns PLAIN STRING for TypeScript!)
export async function run_review_ffi(prompt) {
  console.log("[Review FFI] Running review...");
  try {
    if (typeof initTheme === 'function') {
      await initTheme();
    }
    
    // For now, return placeholder (real Pi SDK call later)
    // TODO: Actually send prompt to Pi session and get response
    const response = "Review completed (placeholder). Score: 70/100. Findings: Code looks good overall.";
    
    console.log("[Review FFI] ✅ Review done, returning string");
    return response; // PLAIN STRING!
  } catch (error) {
    console.error("[Review FFI] ❌ Failed:", error.message);
    return "Review failed: " + error.message;
  }
}
