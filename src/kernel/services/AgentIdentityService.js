// AgentIdentityService.js - Thin wrapper calling Gleam
// STRATEGY: Same class/function names = drop-in replacement!
// NO logic here - just calls Gleam!

import { get_resolved_identity, list_identities } from '../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/agent_identity.mjs';

export class AgentIdentityService {
  static sessionId = undefined;

  constructor(db) {
    // Thin wrapper - no logic, just calls Gleam
  }

  /**
   * THE ONLY WAY to get agent identity.
   * Single source of truth for agent ID in psypi.
   * SAME function name as TS version!
   */
  static async getResolvedIdentity(permanent = false) {
    // Get context (same as TS version)
    const source = process.env.PSYPI_AGENT_SOURCE || process.env.NEZHA_AGENT_SOURCE || 'psypi';
    const sessionId = AgentIdentityService.sessionId || '';

    // For now, use defaults (will enhance later)
    const project = '';
    const gitHash = '';
    const machineFingerprint = '';
    const model = '';

    // Call Gleam function (SAME param names as TS!)
    const result = await get_resolved_identity(
      permanent,
      sessionId,
      project,
      gitHash,
      machineFingerprint,
      source,
      model
    );

    // Convert Gleam Result to JS object
    if (result.Ok) {
      return {
        id: result.Ok.id,
        project: result.Ok.project || null,
        gitHash: result.Ok.git_hash || null,
        machineFingerprint: result.Ok.machine_fingerprint,
        createdAt: new Date(result.Ok.created_at),
        displayName: result.Ok.display_name || undefined,
        description: result.Ok.description || undefined,
        source: result.Ok.source || undefined,
      };
    } else {
      throw new Error(`Failed to get identity: ${JSON.stringify(result.Error)}`);
    }
  }

  /**
   * List agent identities
   * SAME function name as TS version!
   */
  async list(limit = 20) {
    const result = await list_identities(limit);

    if (result.Ok) {
      return result.Ok.map(id => ({
        id: id.id,
        project: id.project || null,
        gitHash: id.git_hash || null,
        machineFingerprint: id.machine_fingerprint,
        createdAt: new Date(id.created_at),
        displayName: id.display_name || undefined,
        description: id.description || undefined,
        source: id.source || undefined,
      }));
    } else {
      return [];
    }
  }
}
