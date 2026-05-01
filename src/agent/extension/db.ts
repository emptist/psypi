import { Pool, PoolClient } from "pg";
import { execSync } from "child_process";
import path from "path";
import fs from "fs";

export interface DbConfig {
  host?: string;
  user?: string;
  database?: string;
  password?: string;
  port?: number;
}

let pool: Pool | null = null;
let dbConfig: DbConfig = {
  host: process.env.PSYPI_DB_HOST || process.env.NUPI_DB_HOST || "127.0.0.1",
  user: process.env.PSYPI_DB_USER || process.env.NUPI_DB_USER || "postgres",
  database: process.env.PSYPI_DB_NAME || process.env.NUPI_DB_NAME || "psypi",
  port: parseInt(process.env.PSYPI_DB_PORT || process.env.NUPI_DB_PORT || "5432"),
  password: process.env.PSYPI_DB_PASSWORD || process.env.NUPI_DB_PASSWORD || "",
};

export function setDbConfig(config: Partial<DbConfig>): void {
  dbConfig = { ...dbConfig, ...config };
}

export function getPool(): Pool {
  if (!pool) {
    pool = new Pool({
      host: dbConfig.host,
      user: dbConfig.user,
      database: dbConfig.database,
      password: dbConfig.password,
      port: dbConfig.port ?? 5432,
    });
  }
  return pool;
}

export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}

export async function querySafe<T extends Record<string, any> = any>(
  sql: string,
  params: any[] = []
): Promise<T[]> {
  try {
    const result = await getPool().query<T>(sql, params);
    return result.rows;
  } catch (e) {
    console.error(`[NuPI DB] ${e instanceof Error ? e.message : String(e)}`);
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
    await getPool().query(sql, params);
    return true;
  } catch (e) {
    console.error(`[NuPI DB] ${e instanceof Error ? e.message : String(e)}`);
    return false;
  }
}

export async function transaction<T>(
  callback: (client: PoolClient) => Promise<T>
): Promise<T | null> {
  const client = await getPool().connect();
  try {
    await client.query("BEGIN");
    const result = await callback(client);
    await client.query("COMMIT");
    return result;
  } catch (e) {
    await client.query("ROLLBACK");
    console.error(`[NuPI DB TX] ${e instanceof Error ? e.message : String(e)}`);
    return null;
  } finally {
    client.release();
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
    const output = execSync("nezha context --json", {
      encoding: "utf-8",
      timeout: 10000,
    }).trim();
    return output;
  } catch (e) {
    console.error(`[NuPI] Failed to get nezha context: ${e instanceof Error ? e.message : String(e)}`);
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
    console.log(`[NuPI] Registered project: ${projectName} (${type}) fingerprint=${fingerprint}`);
  }
  
  return { fingerprint, name: projectName, type, gitRemote, path: cwd };
}
