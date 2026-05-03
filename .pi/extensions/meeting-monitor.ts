/**
 * Meeting Monitor Extension for Pi
 * 
 * Automatically monitors meeting 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1
 * and sends reminders to check progress at set intervals.
 * 
 * Features:
 * - Hooks into tool_result to detect meeting opinions
 * - Sets up periodic check-in reminders (every 10 minutes)
 * - Notifies when Coder AI adds opinions
 * - Can be configured via flags
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  const MEETING_ID = "7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1";
  const CHECK_INTERVAL_MS = 10 * 60 * 1000; // 10 minutes
  
  let checkInterval: ReturnType<typeof setInterval> | null = null;
  let lastOpinionCount = 0;
  let isMonitoring = false;

  // Flag to enable/disable monitoring
  pi.registerFlag("meeting-monitor", {
    description: "Enable automatic meeting progress monitoring",
    type: "boolean",
    default: true,
  });

  // Command to manually check meeting
  pi.registerCommand("check-meeting", {
    description: "Check meeting 7b3e9f1a progress",
    handler: async (_args, ctx) => {
      await checkMeetingProgress(ctx);
    },
  });

  // Command to start/stop monitoring
  pi.registerCommand("meeting-monitor", {
    description: "Start or stop meeting monitoring (usage: /meeting-monitor start|stop)",
    handler: async (args, ctx) => {
      if (args === "start") {
        startMonitoring(ctx);
      } else if (args === "stop") {
        stopMonitoring(ctx);
      } else {
        ctx.ui.notify("Usage: /meeting-monitor start|stop", "info");
      }
    },
  });

  // Hook into session start to begin monitoring
  pi.on("session_start", async (_event, ctx) => {
    if (pi.getFlag("meeting-monitor") && !isMonitoring) {
      startMonitoring(ctx);
    }
  });

  // Hook into tool_result to detect meeting opinion additions
  pi.on("tool_result", async (event, ctx) => {
    // Check if this was a psypi meeting opinion command
    if (event.toolName === "bash" && event.input?.command?.includes("psypi meeting opinion")) {
      // Wait a bit for DB to update
      setTimeout(async () => {
        await checkMeetingProgress(ctx);
      }, 1000);
    }

    // Also check for psypi-meeting-opinion tool if it exists
    if (event.toolName === "psypi-meeting-opinion") {
      setTimeout(async () => {
        await checkMeetingProgress(ctx);
      }, 1000);
    }
  });

  // Hook into agent_end to do periodic summary
  pi.on("agent_end", async (_event, ctx) => {
    if (!isMonitoring) return;
    
    // Check if it's been a while since last check
    const entries = ctx.sessionManager.getEntries();
    const lastEntry = entries[entries.length - 1];
    
    if (lastEntry?.timestamp) {
      const now = Date.now();
      const timeSinceLastCheck = now - (lastOpinionCount > 0 ? lastEntry.timestamp : 0);
      
      if (timeSinceLastCheck > CHECK_INTERVAL_MS) {
        await checkMeetingProgress(ctx);
      }
    }
  });

  function startMonitoring(ctx: any) {
    if (isMonitoring) {
      ctx.ui.notify("Meeting monitor already running", "info");
      return;
    }

    isMonitoring = true;
    ctx.ui.notify("🔄 Meeting monitor started (checking every 10 min)", "success");
    
    // Initial check
    checkMeetingProgress(ctx);
    
    // Set up periodic checks
    checkInterval = setInterval(() => {
      checkMeetingProgress(ctx);
    }, CHECK_INTERVAL_MS);
  }

  function stopMonitoring(ctx: any) {
    if (!isMonitoring) {
      ctx.ui.notify("Meeting monitor not running", "info");
      return;
    }

    isMonitoring = false;
    if (checkInterval) {
      clearInterval(checkInterval);
      checkInterval = null;
    }
    ctx.ui.notify("⏹ Meeting monitor stopped", "info");
  }

  async function checkMeetingProgress(ctx: any) {
    try {
      // Use psypi meeting show to get opinion count
      const result = await ctx.exec?.("psypi", ["meeting", "show", MEETING_ID], { timeout: 5000 });
      
      if (result?.exitCode === 0) {
        const output = result.output || "";
        const opinionMatch = output.match(/Opinions \((\d+)\):/);
        
        if (opinionMatch) {
          const currentCount = parseInt(opinionMatch[1]);
          
          if (currentCount > lastOpinionCount) {
            const newOpinions = currentCount - lastOpinionCount;
            ctx.ui.notify(
              `🆕 ${newOpinions} new opinion(s) in meeting 7b3e9f1a! Total: ${currentCount}`,
              "info"
            );
            lastOpinionCount = currentCount;
          }
        }
        
        ctx.ui.setStatus("meeting", `Meeting: ${currentCount} opinions`);
      }
    } catch (error) {
      // Silently fail - don't disrupt the user
      console.error("Meeting monitor error:", error);
    }
  }

  // Cleanup on shutdown
  pi.on("session_shutdown", async (_event, _ctx) => {
    stopMonitoring(_ctx);
  });
}
