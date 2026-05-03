import { PoolClient } from "pg";
import { DatabaseClient } from "../../kernel/db/DatabaseClient.js";
import { execSync } from "child_process";
import path from "path";
import fs from "fs";

// DatabaseClient singleton is used instead of separate Pool
export function setDbConfig(_config: any): void {
  // No-op: DatabaseClient manages its own config
}

function getDb(): DatabaseClient {
  return DatabaseClient.getInstance();
}

export async function closePool(): Promise<void> {
  DatabaseClient.resetInstance();
}

export async function querySafe<T extends Record<string, any> = any>(
  sql: string,
  params: any[] = []
): Promise<T[]> {
  try {
    const db = getDb();
    const result = await db.query<T>(sql, params);
    return result.rows;
  } catch (e) {
    console.error(`[PsyPI DB] ${e instanceof Error ? e.message : String(e)}`);
    return [];
  }
}

export async function queryOne<T extends Record<string, any> = any>(
  sql: string,
  params: any[] = []
): Promise<T | null> {
  const rows = await querySafe<T>(sql, params);
  return rows.length > 0 ? rows[0]! : null;
}

export async function execSafe(
  sql: string,
  params: any[] = []
): Promise<boolean> {
  try {
    const db = getDb();
    await db.query(sql, params);
    return true;
  } catch (e) {
    console.error(`[PsyPI DB] ${e instanceof Error ? e.message : String(e)}`);
    return false;
  }
}

export async function transaction<T>(
  callback: (client: PoolClient) => Promise<T>
): Promise<T | null> {
  // Note: DatabaseClient doesn't expose PoolClient directly
  // This is a simplified version
  try {
    const result = await callback({} as PoolClient);
    return result;
  } catch (e) {
    console.error(`[PsyPI DB TX] ${e instanceof Error ? e.message : String(e)}`);
    return null;
  }
}

export function validateIdentifier(id: string): boolean {
  return /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(id);
}

export async function resolveId(table: string, shortId: string): Promise<string | null> {
  if (!validateIdentifier(table)) return null;
  const row = await queryOne<{ id: string }>(
    `SELECT id FROM ${table} WHERE id::text LIKE $1 LIMIT 1`,
    [shortId + "%"]
  );
  return row?.id ?? null;
}

export async function getNezhaContext(): Promise<string | null> {
  try {
    const { execSync } = await import("child_process");
    const output = execSync("psypi context --json", {
      encoding: "utf-8",
      timeout: 10000,
    }).trim();
    return output;
  } catch (e) {
    console.error(`[PsyPI] Failed to get psypi context: ${e instanceof Error ? e.message : String(e)}`);
    return null;
  }
}

import { createHash } from "crypto";

export interface ProjectInfo {
  fingerprint: string;
  name: string;
  type: string;
  gitRemote: string | null;
  path: string;
}

export function generateFingerprint(gitRemote: string | null, cwd: string): string {
  const source = gitRemote || cwd;
  return createHash("sha256").update(source).digest("hex").substring(0, 16);
}

export function detectProjectType(cwd: string): string {
  if (fs.existsSync(path.join(cwd, "Package.json")) || fs.existsSync(path.join(cwd, "package.json"))) {
    return "node";
  }
  if (fs.existsSync(path.join(cwd, "pyproject.toml")) || fs.existsSync(path.join(cwd, "setup.py"))) {
    return "python";
  }
  const files = fs.readdirSync(cwd);
  if (files.some((f: string) => f.endsWith(".xcodeproj") || f.endsWith(".xcworkspace"))) {
    return "swift";
  }
  if (fs.existsSync(path.join(cwd, "Cargo.toml"))) {
    return "rust";
  }
  if (fs.existsSync(path.join(cwd, "go.mod"))) {
    return "go";
  }
  return "unknown";
}

export async function registerProject(cwd: string): Promise<ProjectInfo | null> {
  let gitRemote: string | null = null;
  try {
    gitRemote = execSync("git remote get-url origin 2>/dev/null", {
      cwd,
      encoding: "utf-8",
    }).trim();
  } catch {
    gitRemote = null;
  }
  
  const fingerprint = generateFingerprint(gitRemote, cwd);
  const projectName = path.basename(cwd);
  const type = detectProjectType(cwd);
  
  const existing = await queryOne<{ id: string }>(
    "SELECT id FROM projects WHERE fingerprint = $1",
    [fingerprint]
  );
  
  if (existing) {
    await execSafe(
      "UPDATE projects SET last_seen = NOW() WHERE fingerprint = $1",
      [fingerprint]
    );
    return { fingerprint, name: projectName, type: type, gitRemote, path: cwd };
  }
  
  const inserted = await queryOne<{ id: string }>(
    `INSERT INTO projects (fingerprint, name, path, language, status)
     VALUES ($1, $2, $3, $4, 'ACTIVE')
     ON CONFLICT (fingerprint) DO UPDATE SET last_seen = NOW(), name = EXCLUDED.name
     RETURNING id`,
    [fingerprint, projectName, cwd, type]
  );
  
  if (inserted) {
    console.log(`[PsyPI] Registered project: ${projectName} (${type}) fingerprint=${fingerprint}`);
  }
  
  return { fingerprint, name: projectName, type, gitRemote, path: cwd };
}
