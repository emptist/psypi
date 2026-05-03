/**
 * DatabaseClient interface for psypi
 * Minimal version matching psypi's interface
 */

import { type QueryResultRow, type QueryResult } from 'pg';

export interface DatabaseClient {
  query<T extends QueryResultRow = QueryResultRow>(
    sql: string,
    params?: unknown[]
  ): Promise<QueryResult<T>>;
  config: any;
  isClosed: boolean;
  close(): Promise<void>;
  
  // Optional methods (may not be used but needed for interface)
  getGitBranch?: () => Promise<string | null>;
  healthCheck?: () => Promise<boolean>;
  getPoolStats?: () => any;
  setCurrentAgent?: (agentId: string) => void;
  getCurrentAgent?: () => string | null;
  setProjectContext?: (project: string, root: string) => void;
  getProjectContext?: () => any;
}
