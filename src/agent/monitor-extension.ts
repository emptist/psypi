// Monitor Partner AI Extension - Background support for autonomous work! 🤖
// He does housekeeping, skills management, data prep, meeting organization!

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

// Get the directory of this module
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Resolve Gleam build path relative to project root
const gleamBuildPath = resolve(__dirname, '../../gleam/psypi_core/build/dev/javascript');

// Dynamic import helper that works with both ts and js
async function importGleam(modulePath: string) {
  const fullPath = resolve(gleamBuildPath, 'psypi_core/psypi_cli', modulePath);
  return await import(fullPath);
}

export default function (pi: ExtensionAPI) {
  console.log("[Monitor AI] Starting background support... 🤖");

  // Start Monitor AI when session starts
  pi.on("session_start", async (_event, _ctx) => {
    try {
      // @ts-ignore: Gleam .mjs has no type declarations
      const { start_monitor_loop } = await importGleam("monitor_ai.mjs");
      start_monitor_loop();
      console.log("[Monitor AI] Started! 🤖");
    } catch (err: any) {
      console.error("[Monitor AI] Failed to start:", err.message);
    }
  });

  // Housekeeping tool (calls Monitor AI)
  pi.registerTool({
    name: "psypi-monitor-housekeeping",
    label: "Monitor Housekeeping",
    description: "Trigger housekeeping (auto-backup, cleanup)",
    parameters: Type.Object({}),
    async execute(_toolCallId: string, _params: any) {
      try {
        // @ts-ignore: Gleam .mjs has no type declarations
        const { housekeeping } = await importGleam("monitor_ai.mjs");
        housekeeping();
        return {
          content: [{ type: "text" as const, text: "Housekeeping triggered! 🧹" }],
          details: { success: true } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // System health check tool
  pi.registerTool({
    name: "psypi-monitor-health",
    label: "Monitor Health Check",
    description: "Check system health (DB, builds, disk)",
    parameters: Type.Object({}),
    async execute(_toolCallId: string, _params: any) {
      try {
        // @ts-ignore: Gleam .mjs has no type declarations
        const { check_system_health } = await importGleam("monitor_ai.mjs");
        const result = await check_system_health();
        return {
          content: [{ type: "text" as const, text: `Health check: ${JSON.stringify(result)}` }],
          details: { result } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  console.log("[Monitor AI] Extension loaded! 🤖 Ready to support autonomous work!");
}
