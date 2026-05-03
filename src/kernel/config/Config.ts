import {
  type DbConfig,
  type TaskConfig,
  type MemoryConfig,
  type HealthConfig,
  type EmbeddingConfig,
  type PsypiConfig,
  type IConfig,
  type TransportConfig,
} from './types.js';
import { logger } from '../utils/logger.js';
import {
  DATABASE_CONFIG,
  TASK_CONFIG,
  MEMORY_CONFIG,
  ENV_KEYS,
  ENV_DEFAULT,
  OPENCODE_API,
} from './constants.js';
import { loadYamlConfig, type PsypiYamlConfig } from './YamlConfigLoader.js';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import * as os from 'os';
import { AgentIdentityService } from '../services/AgentIdentityService.js';
import { config } from 'dotenv';
config();

function parseIntEnv(value: string | undefined, defaultValue: number, key: string): number {
  if (!value) return defaultValue;
  const parsed = parseInt(value, 10);
  if (isNaN(parsed)) {
    throw new Error(`Invalid value for ${key}: "${value}" is not a valid integer`);
  }
  return parsed;
}

// Agent ID resolution function - to be called async after config is ready
export async function resolveAgentIdAsync(
  config: IConfig
): Promise<{ id: string; displayName?: string }> {
  const envAgentId = process.env[ENV_KEYS.AGENT_ID] || process.env.PSYPI_AGENT_ID;
  if (envAgentId && envAgentId.trim()) {
    const displayName = process.env[ENV_KEYS.AGENT_NAME] || process.env.PSYPI_AGENT_NAME;
    return {
      id: envAgentId,
      displayName: displayName || undefined,
    };
  }

  const { AgentIdentityService } = await import('../services/AgentIdentityService.js');
  const identity = await AgentIdentityService.getResolvedIdentity();

  logger.info(`[AgentIdentity] Resolved identity: ${identity.id}`);
  return {
    id: identity.id,
    displayName: identity.displayName,
  };
}

// Sync wrapper - returns env var or empty (async resolution should be used for real ID)
function loadOrCreateAgentId(): { id: string; displayName?: string } {
  const envAgentId = process.env[ENV_KEYS.AGENT_ID] || process.env.PSYPI_AGENT_ID;
  if (envAgentId && envAgentId.trim()) {
    const displayName = process.env[ENV_KEYS.AGENT_NAME] || process.env.PSYPI_AGENT_NAME;
    return {
      id: envAgentId,
      displayName: displayName || undefined,
    };
  }

  return {
    id: '',
    displayName: undefined,
  };
}

export class Config implements IConfig {
  private static instance: Config | null = null;
  private readonly config: PsypiConfig;

  private constructor() {
    this.config = this.loadConfig();
  }

  static getInstance(): Config {
    if (!Config.instance) {
      Config.instance = new Config();
    }
    return Config.instance;
  }

  static resetInstance(): void {
    Config.instance = null;
  }

  private loadConfig(): PsypiConfig {
    const yamlResult = loadYamlConfig();
    const yamlConfig = yamlResult.config;

    if (!yamlResult.valid) {
      logger.warn('YAML config validation warnings:', yamlResult.errors);
    }

    const dbConfig = this.loadDbConfig(yamlConfig);
    const taskConfig = this.loadTaskConfig(yamlConfig);
    const memoryConfig = this.loadMemoryConfig();
    const healthConfig = this.loadHealthConfig(yamlConfig);
    const embeddingConfig = this.loadEmbeddingConfig(yamlConfig);
    const transportConfig = this.loadTransportConfig(yamlConfig);
    const env = this.loadEnv();
    const agent = loadOrCreateAgentId();

    return {
      db: dbConfig,
      task: taskConfig,
      memory: memoryConfig,
      health: healthConfig,
      embedding: embeddingConfig,
      env,
      transport: transportConfig,
      agentId: agent.id,
      agentDisplayName: agent.displayName,
    };
  }

  private loadDbConfig(yaml?: PsypiYamlConfig): DbConfig {
    return {
      host: process.env[ENV_KEYS.DB_HOST],
      port: process.env[ENV_KEYS.DB_PORT] ? parseInt(process.env[ENV_KEYS.DB_PORT]!) : undefined,
      // CRITICAL FIX: Default to 'psypi' database, not undefined!
      database: process.env[ENV_KEYS.DB_NAME] || 'psypi',
      user: process.env[ENV_KEYS.DB_USER],
      password: process.env[ENV_KEYS.DB_PASSWORD],
      max: process.env[ENV_KEYS.DB_MAX] ? parseInt(process.env[ENV_KEYS.DB_MAX]!) : undefined,
      idleTimeoutMillis: DATABASE_CONFIG.DEFAULT_IDLE_TIMEOUT_MS,
      connectionTimeoutMillis: DATABASE_CONFIG.DEFAULT_CONNECTION_TIMEOUT_MS,
    };
  }

  private loadTaskConfig(yaml?: PsypiYamlConfig): TaskConfig {
    return {
      heartbeatIntervalMs: parseIntEnv(
        process.env[ENV_KEYS.HEARTBEAT_INTERVAL] || process.env.HEARTBEAT_INTERVAL_MS,
        yaml?.task?.heartbeatIntervalMs || TASK_CONFIG.DEFAULT_HEARTBEAT_INTERVAL_MS,
        ENV_KEYS.HEARTBEAT_INTERVAL
      ),
      maxRetries: parseIntEnv(
        process.env[ENV_KEYS.RETRY_MAX_ATTEMPTS] || process.env[ENV_KEYS.MAX_RETRIES],
        yaml?.task?.maxRetries || TASK_CONFIG.DEFAULT_MAX_RETRIES,
        ENV_KEYS.RETRY_MAX_ATTEMPTS
      ),
      retryDelayMs: parseIntEnv(
        process.env[ENV_KEYS.RETRY_DELAY_MS] || process.env[ENV_KEYS.RETRY_DELAY],
        yaml?.task?.retryDelayMs || TASK_CONFIG.DEFAULT_RETRY_DELAY_MS,
        ENV_KEYS.RETRY_DELAY_MS
      ),
      taskTimeoutMs: parseIntEnv(
        process.env[ENV_KEYS.TASK_TIMEOUT],
        yaml?.task?.taskTimeoutMs || TASK_CONFIG.DEFAULT_TASK_TIMEOUT_MS,
        ENV_KEYS.TASK_TIMEOUT
      ),
    };
  }

  private loadMemoryConfig(): MemoryConfig {
    return {
      bootstrapDir:
        process.env[ENV_KEYS.MEMORY_BOOTSTRAP_DIR] || MEMORY_CONFIG.DEFAULT_BOOTSTRAP_DIR,
      maxMemoryAgeMs: parseIntEnv(
        process.env[ENV_KEYS.MAX_MEMORY_AGE],
        MEMORY_CONFIG.DEFAULT_MAX_MEMORY_AGE_MS,
        ENV_KEYS.MAX_MEMORY_AGE
      ),
    };
  }

  private loadHealthConfig(yaml?: PsypiYamlConfig): HealthConfig {
    return {
      port: parseIntEnv(
        process.env[ENV_KEYS.HEALTH_PORT] || process.env.PSYPI_HEALTH_PORT,
        yaml?.health?.port || 4097,
        'PSYPI_HEALTH_PORT / NEZHA_HEALTH_PORT'
      ),
      requireAuth: yaml?.health?.requireAuth ?? false,
    };
  }

  private loadEmbeddingConfig(yaml?: PsypiYamlConfig): EmbeddingConfig | undefined {
    const provider = process.env[ENV_KEYS.EMBEDDING_PROVIDER] || yaml?.embedding?.provider;
    if (!provider) {
      return undefined;
    }

    if (provider !== 'ollama' && provider !== 'zhipu' && provider !== 'openai') {
      return undefined;
    }

    return {
      provider,
      model:
        process.env[ENV_KEYS.EMBEDDING_MODEL] ||
        yaml?.embedding?.model ||
        (provider === 'ollama' ? 'nomic-embed-text' : 'embedding-2'),
      apiKey: process.env[ENV_KEYS.ZHIPU_API_KEY] || yaml?.embedding?.apiKey,
      apiUrl: process.env[ENV_KEYS.EMBEDDING_API_URL] || yaml?.embedding?.apiUrl,
    };
  }

  private loadEnv(): 'development' | 'production' | 'test' {
    const env = process.env[ENV_KEYS.ENV] || ENV_DEFAULT.DEVELOPMENT;
    if (
      env === ENV_DEFAULT.DEVELOPMENT ||
      env === ENV_DEFAULT.PRODUCTION ||
      env === ENV_DEFAULT.TEST
    ) {
      return env;
    }
    return ENV_DEFAULT.DEVELOPMENT;
  }

  private detectOpencodePort(): number {
    const envPort = process.env[ENV_KEYS.OPENCODE_PORT];
    if (envPort) {
      const parsed = parseInt(envPort, 10);
      if (!isNaN(parsed) && parsed > 0 && parsed < 65536) {
        return parsed;
      }
    }

    const homeDir = os.homedir();
    const opencodeConfigPaths = [
      path.join(homeDir, '.config', 'opencode', 'config.yaml'),
      path.join(homeDir, '.config', 'opencode', 'config.yml'),
      path.join(homeDir, '.opencode.yaml'),
      path.join(homeDir, '.opencode.yml'),
    ];

    for (const configPath of opencodeConfigPaths) {
      try {
        if (fs.existsSync(configPath)) {
          const content = fs.readFileSync(configPath, 'utf-8');
          const config = content.includes('port:')
            ? content
            : content.replace(/serve:/, 'serve:\n  port:');

          const portMatch = config.match(/port:\s*(\d+)/);
          if (portMatch && portMatch[1]) {
            return parseInt(portMatch[1], 10);
          }
        }
      } catch {
        // Continue to next path
      }
    }

    return OPENCODE_API.DEFAULT_PORT;
  }

  private loadTransportConfig(yaml?: PsypiYamlConfig): TransportConfig {
    const envUrl = process.env[ENV_KEYS.OPENCODE_API_URL];
    const yamlUrl = yaml?.transport?.opencodeApiUrl;

    let opencodeApiUrl: string;
    if (envUrl) {
      const port = this.detectOpencodePort();
      const urlObj = new URL(envUrl);
      urlObj.port = String(port);
      opencodeApiUrl = urlObj.toString();
    } else if (yamlUrl) {
      const port = this.detectOpencodePort();
      const urlObj = new URL(yamlUrl);
      urlObj.port = String(port);
      opencodeApiUrl = urlObj.toString();
    } else {
      const port = this.detectOpencodePort();
      opencodeApiUrl = `http://localhost:${port}`;
    }

    return {
      mode: 'http',
      opencodeApiUrl: opencodeApiUrl.replace(/\/+$/, ''),
    };
  }

  getDbConfig(): DbConfig {
    return { ...this.config.db };
  }

  getTaskConfig(): TaskConfig {
    return { ...this.config.task };
  }

  getMemoryConfig(): MemoryConfig {
    return { ...this.config.memory };
  }

  getHealthConfig(): HealthConfig {
    return { ...this.config.health };
  }

  getEmbeddingConfig(): EmbeddingConfig | undefined {
    return this.config.embedding ? { ...this.config.embedding } : undefined;
  }

  getEnv(): string {
    return this.config.env;
  }

  getTransportConfig(): TransportConfig {
    return { ...this.config.transport };
  }

  async getAgentIdAsync(): Promise<string> {
    const { AgentIdentityService } = await import('../services/AgentIdentityService.js');
    const identity = await AgentIdentityService.getResolvedIdentity();
    return identity.id;
  }

  getAgentDisplayName(): string | undefined {
    return this.config.agentDisplayName;
  }

  getAgentName(): string {
    return this.config.agentId;
  }

  validate(): boolean {
    if (!this.config.db.host || this.config.db.host.trim() === '') {
      return false;
    }
    if (!this.config.db.port || this.config.db.port <= 0 || this.config.db.port > 65535) {
      return false;
    }
    if (!this.config.db.database || this.config.db.database.trim() === '') {
      return false;
    }
    if (!this.config.db.user || this.config.db.user.trim() === '') {
      return false;
    }
    // Password can be empty for Keychain/trust authentication
    // Removed: if (!this.config.db.password || this.config.db.password.trim() === '')
    if (!this.config.task.heartbeatIntervalMs || this.config.task.heartbeatIntervalMs <= 0) {
      return false;
    }
    if (this.config.task.maxRetries < 0) {
      return false;
    }
    return true;
  }
}
