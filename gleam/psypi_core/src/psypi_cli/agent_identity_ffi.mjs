import { DatabaseClient } from '../../../src/kernel/db/DatabaseClient.js';
import { execSync } from 'node:child_process';
import os from 'node:os';
import crypto from 'node:crypto';

const INNER_FALLBACK_MODEL = 'llama3.2:3b';

export function get_project_name() {
  try {
    const remote = execSync('git remote get-url origin 2>/dev/null || echo ""', {
      encoding: 'utf-8',
      cwd: process.cwd(),
    }).trim();
    if (remote) {
      const match = remote.match(/\/([^/]+?)(?:\.git)?$/);
      if (match && match[1]) return { Some: [match[1]] };
    }
  } catch {}
  return { None: [] };
}

export function get_git_hash() {
  try {
    const hash = execSync('git rev-parse --short HEAD 2>/dev/null', {
      encoding: 'utf-8',
      cwd: process.cwd(),
    }).trim();
    if (hash) return { Some: [hash] };
  } catch {}
  return { None: [] };
}

export function get_machine_fingerprint() {
  const info = [os.hostname(), os.platform(), os.arch(), os.cpus()[0]?.model || 'unknown'].join('|');
  return crypto.createHash('sha256').update(info).digest('hex').substring(0, 16);
}

export function get_source() {
  return process.env.PSYPI_AGENT_SOURCE || process.env.NEZHA_AGENT_SOURCE || 'psypi';
}

export function get_cwd() {
  return process.cwd();
}

export async function resolve_inner_model() {
  try {
    const db = DatabaseClient.getInstance();
    const result = await db.query(
      `SELECT model FROM api_keys WHERE service = 'inner' AND is_active = true LIMIT 1`
    );
    if (result.rows.length > 0) {
      return result.rows[0].model;
    }
  } catch {}
  return INNER_FALLBACK_MODEL;
}

export async function get_or_create_identity(
  id,
  project,
  git_hash,
  machine_fingerprint,
  source,
  session_id
) {
  const db = DatabaseClient.getInstance();
  
  const existing = await db.query(
    `SELECT id, project, git_hash, machine_fingerprint, created_at, display_name, description, source
     FROM agent_identities WHERE id = $1`,
    [id]
  );
  
  if (existing.rows.length > 0) {
    const row = existing.rows[0];
    return {
      id: row.id,
      project: row.project ? { Some: [row.project] } : { None: [] },
      git_hash: row.git_hash ? { Some: [row.git_hash] } : { None: [] },
      machine_fingerprint: row.machine_fingerprint ? { Some: [row.machine_fingerprint] } : { None: [] },
      created_at: row.created_at?.toISOString() || '',
      display_name: row.display_name ? { Some: [row.display_name] } : { None: [] },
      description: row.description ? { Some: [row.description] } : { None: [] },
      source: row.source ? { Some: [row.source] } : { None: [] },
    };
  }
  
  await db.query(
    `INSERT INTO agent_identities (id, project, git_hash, machine_fingerprint, source, session_id)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [
      id,
      project?.Some?.[0] || null,
      git_hash?.Some?.[0] || null,
      machine_fingerprint,
      source,
      session_id?.Some?.[0] || null,
    ]
  );
  
  return {
    id,
    project,
    git_hash,
    machine_fingerprint: { Some: [machine_fingerprint] },
    created_at: new Date().toISOString(),
    display_name: { None: [] },
    description: { None: [] },
    source: { Some: [source] },
  };
}
