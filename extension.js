// extension.js - Pi TUI Extension for psypi
// Located in root directory - relative paths based on this location!

import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Dynamic imports - paths relative to this file in root directory
const getAgentIdentityModule = () => import("./gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/agent_identity.mjs");
const getAgentIdentityService = async () => {
  const module = await import("./src/kernel/services/AgentIdentityService.js");
  return module.AgentIdentityService;
};

// Initialize extension - Pi REQUIRES this structure!
export default function (pi) {
  const VERBOSE = process.env.PSYPI_VERBOSE === 'true';

  if (VERBOSE) {
    console.log(`[PsyPI] Extension loaded from ${__dirname}`);
  }

  // Set sessionId at session start
  pi.on("session_start", async (_event, ctx) => {
    const sessionId = ctx?.sessionManager?.getSessionId();
    const AgentIdentityService = await getAgentIdentityService();
    AgentIdentityService.sessionId = sessionId;
    if (VERBOSE) {
      console.log(`[PsyPI] Session ID: ${sessionId}`);
    }
  });

  // ===== Pi Tool Registrations =====

  // Agent Identity tools
  pi.registerTool({
    name: "psypi-my-id",
    description: "Get current agent ID (e.g., S-psypi-psypi)",
    parameters: {},
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      const AgentIdentityService = await getAgentIdentityService();
      const identity = await AgentIdentityService.getResolvedIdentity();
      return { content: [{ type: "text", text: `My ID: ${identity.id}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-partner-id",
    description: "Get partner/monitor ID (permanent God AI, e.g., P-tencent/hy3-preview:free-psypi)",
    parameters: {},
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      const AgentIdentityService = await getAgentIdentityService();
      const identity = await AgentIdentityService.getResolvedIdentity(true);
      return { content: [{ type: "text", text: `Partner ID: ${identity.id}` }] };
    }
  });

  if (VERBOSE) {
    console.log(`[PsyPI] All tools registered!`);
  }
}
