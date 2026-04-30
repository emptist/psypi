/**
 * Psypi Kernel - Integrated from Nezha
 * 
 * Provides: Database, Tasks, Memory, Skills, Issues
 * No server, no strange things - just core services
 */

import { Pool } from 'pg';
import { config } from 'dotenv';

// Load env
config();

export interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
}

export class Kernel {
  private pool: Pool;
  
  constructor() {
    this.pool = new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'nezha',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
    });
  }
  
  async query(text: string, params?: any[]) {
    const client = await this.pool.connect();
    try {
      const result = await client.query(text, params);
      return result;
    } finally {
      client.release();
    }
  }
  
  async getTasks(status?: string) {
    let query = 'SELECT * FROM tasks';
    const params: any[] = [];
    if (status) {
      query += ' WHERE status = $1';
      params.push(status);
    }
    query += ' ORDER BY created_at DESC LIMIT 50';
    return this.query(query, params);
  }
  
  async addTask(title: string, description: string, priority: number = 5) {
    const result = await this.query(
      `INSERT INTO tasks (id, title, description, status, priority, category, created_by) 
       VALUES (gen_random_uuid(), $1, $2, 'PENDING', $3, 'general', 'psypi') 
       RETURNING id`,
      [title, description, priority]
    );
    return result.rows[0].id;
  }
  
  async getIssues(status?: string) {
    let query = 'SELECT * FROM issues';
    const params: any[] = [];
    if (status) {
      query += ' WHERE status = $1';
      params.push(status);
    }
    query += ' ORDER BY created_at DESC LIMIT 50';
    return this.query(query, params);
  }
  
  async addIssue(title: string, severity: string = 'medium') {
    const result = await this.query(
      `INSERT INTO issues (id, title, severity, status, created_by) 
       VALUES (gen_random_uuid(), $1, $2, 'open', 'psypi') 
       RETURNING id`,
      [title, severity]
    );
    return result.rows[0].id;
  }
  
  async close() {
    await this.pool.end();
  }
}

// Export singleton
export const kernel = new Kernel();
