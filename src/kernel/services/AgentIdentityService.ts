import { DatabaseClient } from '../db/DatabaseClient.js';
import { logger } from '../utils/logger.js';
import { ApiKeyService } from './ApiKeyService.js';
import * as crypto from 'node:crypto';
import { execSync } from 'node:child_process';
import os from 'node:os';

const INNER_FALLBACK_MODEL = 'llama3.2:3b';

export interface AgentIdentity {
  id: string;
  project: string | null;
  gitHash: string | null;
  machineFingerprint: string | null;
  createdAt: Date;
  displayName?: string;
  description?: string;
  source?: string;
}

interface IdentityRow {
  id: string;
  project: string | null;
  git_hash: string | null;
  machine_fingerprint: string | null;
  created_at: Date;
  display_name: string | null;
  description: string | null;
  source: string | null;
}

export class AgentIdentityService {
  private db: DatabaseClient;

  static sessionId: string | undefined;

  constructor(db: DatabaseClient) {
    this.db = db;
  }

  /**
   * THE ONLY WAY to get agent identity.
   * Single source of truth for agent ID in psypi.
   */
  static async getResolvedIdentity(permanent: boolean = false): Promise<AgentIdentity> {
    const db = DatabaseClient.getInstance();
    const service = new AgentIdentityService(db);
    return service.resolve(permanent);
  }

  private async resolve(permanent?: boolean): Promise<AgentIdentity> {
    const context = await this.detectContext(permanent);
    return this.createIdentity(context);
  }

  private async detectContext(permanent?: boolean) {
    const source = process.env.PSYPI_AGENT_SOURCE || process.env.NEZHA_AGENT_SOURCE || 'psypi';
    const sessionId = AgentIdentityService.sessionId;

    let model: string | undefined;
    if (permanent) {
      model = await this.resolveInnerModel();
    }

    return {
      project: this.getProjectName(),
      gitHash: this.getGitHash(),
      machineFingerprint: this.getMachineFingerprint(),
      cwd: process.cwd(),
      source: source as 'psypi' | 'opencode' | 'external' | 'mcp',
      sessionId,
      permanent,
      model,
    };
  }

  private async resolveInnerModel(): Promise<string> {
    const apiKeyService = ApiKeyService.getInstance(this.db);
    try {
      const current = await apiKeyService.getCurrentInnerModel();
      return current?.model || INNER_FALLBACK_MODEL;
    } catch (error) {
      logger.warn(`[AgentIdentity] Failed to resolve inner model: ${error}, using fallback`);
      return INNER_FALLBACK_MODEL;
    }
  }

  private getProjectName(): string | null {
    try {
      const remote = execSync('git remote get-url origin 2>/dev/null || echo ""', {
        encoding: 'utf-8',
        cwd: process.cwd(),
      }).trim();
      if (remote) {
        const match = remote.match(/\/([^/]+?)(?:\.git)?$/);
        if (match && match[1]) return match[1];
      }
    } catch { }
    return null;
  }

  private getGitHash(): string | null {
    try {
      const hash = execSync('git rev-parse --short HEAD 2>/dev/null', {
        encoding: 'utf-8',
        cwd: process.cwd(),
      }).trim();
      return hash || null;
    } catch {
      return null;
    }
  }

  private getMachineFingerprint(): string {
    const info = [os.hostname(), os.platform(), os.arch(), os.cpus()[0]?.model || 'unknown'].join('|');
    return crypto.createHash('sha256').update(info).digest('hex').substring(0, 16);
  }

  private generateSemanticId(context: any): string {
    const source = context.source || 'unknown';

    if (context.permanent) {
      if (context.model) {
        if (context.project) {
          return context.sessionId ? `P-${context.model}-${context.project}-${context.sessionId}` : `P-${context.model}-${context.project}`;
        }
        return `P-${context.model}`;
      }
      if (context.project) {
        return context.sessionId ? `P-${source}-${context.project}-${context.sessionId}` : `P-${source}-${context.project}`;
      }
      return `P-${source}`;
    }

    if (context.project) {
      return context.sessionId ? `S-${source}-${context.project}-${context.sessionId}` : `S-${source}-${context.project}`;
    }

    const projectName = context.cwd.split('/').pop() || 'unknown';
    return `G-${source}-${projectName}-${context.machineFingerprint}`;
  }

  private async createIdentity(context: any): Promise<AgentIdentity> {
    const source = context.source ?? 'unknown';
    const id = this.generateSemanticId(context);

    try {
      await this.db.query(
        `INSERT INTO agent_identities (id, project, git_hash, machine_fingerprint, source, session_id)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [id, context.project, context.gitHash, context.machineFingerprint, source, context.sessionId || null]
      );
      logger.info(`[AgentIdentity] Created new identity: ${id} (source: ${source})`);
    } catch (err: any) {
      // Ignore duplicate key error - identity already exists
      if (!err.message?.includes('duplicate key')) {
        throw err;
      }
    }

    // Track session
    if (context.sessionId) {
      await this.trackSession(id, context.sessionId, source);
    }

    // Track activity
    await this.trackActivity(id, context.permanent ? 'get_partner_id' : 'get_agent_id', context);

    // Always return from database for tracking
    const identity = await this.getById(id);
    if (!identity) {
      throw new Error(`Failed to retrieve identity ${id} from database`);
    }
    return identity;
  }

  private async trackSession(identityId: string, sessionId: string, source: string): Promise<void> {
    try {
      // One session per identity (identity already contains sessionId)
      const existing = await this.db.query(
        `SELECT id FROM agent_sessions WHERE identity_id = $1`,
        [identityId]
      );

      if (existing.rows.length === 0) {
        await this.db.query(
          `INSERT INTO agent_sessions (identity_id, agent_type, process_id, status, started_at)
           VALUES ($1, $2, $3, 'alive', NOW())`,
          [identityId, source, process.pid]
        );
      }
    } catch (err: any) {
      logger.warn(`[AgentIdentity] Failed to track session: ${err.message}`);
    }
  }

  private async trackActivity(agentId: string, activity: string, context: any): Promise<void> {
    try {
      await this.db.query(
        `INSERT INTO activity_log (agent_id, activity, context, git_hash, git_branch, environment)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [agentId, activity, JSON.stringify({ project: context.project, cwd: context.cwd }), context.gitHash, null, process.env.NODE_ENV || 'development']
      );
    } catch (err: any) {
      logger.warn(`[AgentIdentity] Failed to track activity: ${err.message}`);
    }
  }

  private async getById(id: string): Promise<AgentIdentity | null> {
    const result = await this.db.query<IdentityRow>(
      `SELECT id, project, git_hash, machine_fingerprint, created_at, display_name, description
       FROM agent_identities WHERE id = $1`,
      [id]
    );
    if (result.rows.length === 0) return null;

    const row = result.rows[0]!;
    return {
      id: row.id,
      project: row.project,
      gitHash: row.git_hash,
      machineFingerprint: row.machine_fingerprint,
      createdAt: row.created_at,
      displayName: row.display_name ?? undefined,
      description: row.description ?? undefined,
      source: row.source ?? undefined,
    };
  }

  /**
   * List agent identities (useful for seeing all psypi instances)
   */
  async list(limit = 20): Promise<AgentIdentity[]> {
    const result = await this.db.query<IdentityRow>(
      `SELECT id, project, git_hash, machine_fingerprint, created_at, display_name, description
       FROM agent_identities ORDER BY created_at DESC LIMIT $1`,
      [limit]
    );

    return result.rows.map(row => this.rowToIdentity(row));
  }

  private rowToIdentity(row: IdentityRow): AgentIdentity {
    return {
      id: row.id,
      project: row.project,
      gitHash: row.git_hash,
      machineFingerprint: row.machine_fingerprint,
      createdAt: row.created_at,
      displayName: row.display_name ?? undefined,
      description: row.description ?? undefined,
      source: row.source ?? undefined,
    };
  }
}
