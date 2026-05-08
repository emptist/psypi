// AgentIdentityService.js - Thin wrapper calling Gleam
// STRATEGY: Same class/function names = drop-in replacement!
// NO logic here - just calls Gleam!

import { get_resolved_identity } from '../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/agent_identity.mjs';
import { Ok as OkConstructor } from '../../../gleam/psypi_core/build/dev/javascript/psypi_core/gleam.mjs';

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

    // Call Gleam function
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
    // Gleam Ok(value) is represented as instance of OkConstructor with value at [0]
    if (result instanceof OkConstructor) {
      const id = result[0];
      return {
        id: id.id,
        project: id.project || null,
        gitHash: id.git_hash || null,
        machineFingerprint: id.machine_fingerprint,
        createdAt: new Date(id.created_at),
        displayName: id.display_name || undefined,
        description: id.description || undefined,
        source: id.source || undefined,
      };
    } else {
      throw new Error(`Failed to get identity: ${JSON.stringify(result)}`);
    }
  }

  /**
   * List agent identities
   * SAME function name as TS version!
   */
  async list(limit = 20) {
    // TODO: Implement list_identities in Gleam
    return [];
  }
}
