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

  // Store interval ID for cleanup
  let monitorInterval: NodeJS.Timeout | null = null;

  // Start Monitor AI when session starts
  pi.on("session_start", async (_event, _ctx) => {
    try {
      // @ts-ignore: Gleam .mjs has no type declarations
      const { start_monitor_loop } = await importGleam("monitor_ai.mjs");
      
      // Start the monitor loop (runs in background)
      const loopResult = start_monitor_loop();
      
      // Set up periodic context preparation (every 5 minutes)
      monitorInterval = setInterval(async () => {
        try {
          // @ts-ignore: Gleam .mjs has no type declarations
          const { prepare_context } = await importGleam("monitor_ai.mjs");
          const agentId = pi.getAgentId() || 'S-psypi-psypi';
          const contextResult = await prepare_context(agentId);
          
          if (contextResult && 'Ok' in contextResult) {
            console.log("[Monitor AI] Context prepared, broadcasting...");
            // Broadcast context to worker AI
            await pi.tools.psypiBroadcastSend({
              message: contextResult.Ok,
              priority: 'normal'
            });
          }
        } catch (err: any) {
          console.error("[Monitor AI] Error in periodic context prep:", err.message);
        }
      }, 5 * 60 * 1000); // 5 minutes
      
      console.log("[Monitor AI] Started! 🤖");
    } catch (err: any) {
      console.error("[Monitor AI] Failed to start:", err.message);
    }
  });

  // Cleanup on session end
  pi.on("session_end", (_event, _ctx) => {
    if (monitorInterval) {
      clearInterval(monitorInterval);
      monitorInterval = null;
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

  // Prepare context tool - HELPS WORKER AI WORK FASTER! 💡
  pi.registerTool({
    name: "psypi-monitor-prepare-context",
    label: "Monitor Prepare Context",
    description: "Prepare context for worker AI (learnings, backups, etc.)",
    parameters: Type.Object({
      agent_id: Type.Optional(Type.String({ description: "Agent ID to prepare context for (default: current agent)" })),
    }),
    async execute(_toolCallId: string, params: any) {
      try {
        // @ts-ignore: Gleam .mjs has no type declarations
        const { prepare_context } = await importGleam("monitor_ai.mjs");
        const agentId = params.agent_id || pi.getAgentId() || 'S-psypi-psypi';
        const result = await prepare_context(agentId);
        
        if (result && 'Ok' in result) {
          return {
            content: [{ type: "text" as const, text: result.Ok }],
            details: { success: true, context: result.Ok } as Record<string, unknown>,
          };
        } else {
          return {
            content: [{ type: "text" as const, text: `Error: ${JSON.stringify(result)}` }],
            details: { error: true, result } as Record<string, unknown>,
          };
        }
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
