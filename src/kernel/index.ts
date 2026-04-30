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
  
  async getSkills(approvedOnly: boolean = true) {
    let query = 'SELECT id, name, status, safety_score FROM skills';
    const params: any[] = [];
    if (approvedOnly) {
      query += ' WHERE status = $1 AND safety_score >= $2';
      params.push('approved', 70);
    }
    query += ' ORDER BY name ASC';
    return this.query(query, params);
  }
  
  async getSkillByName(name: string) {
    const result = await this.query(
      'SELECT * FROM skills WHERE name = $1 LIMIT 1',
      [name]
    );
    return result.rows[0] || null;
  }
  
  async reflect(text: string) {
    const results: string[] = [];
    
    // Simple check for [LEARN] marker
    if (text.includes('[LEARN]')) {
      const insight = text.replace('[LEARN]', '').trim();
      await this.query(
        `INSERT INTO memory (content, tags, source, importance) 
         VALUES ($1, ARRAY['learning', 'reflection'], 'areflect', 7)`,
        [insight]
      );
      results.push(`✅ Learning saved: ${insight.substring(0, 60)}...`);
    }
    
    // Simple check for [ISSUE] marker
    if (text.includes('[ISSUE]')) {
      const title = text.replace('[ISSUE]', '').trim();
      const result = await this.query(
        `INSERT INTO issues (id, title, status, created_by) 
         VALUES (gen_random_uuid(), $1, 'open', 'psypi') RETURNING id`,
        [title]
      );
      results.push(`✅ Issue created: ${result.rows[0].id}`);
    }
    
    // Simple check for [TASK] marker
    if (text.includes('[TASK]')) {
      const title = text.replace('[TASK]', '').trim();
      const result = await this.query(
        `INSERT INTO tasks (id, title, status, priority, category, created_by) 
         VALUES (gen_random_uuid(), $1, 'PENDING', 5, 'general', 'psypi') RETURNING id`,
        [title]
      );
      results.push(`✅ Task created: ${result.rows[0].id}`);
    }
    
    return results.join('\n');
  }
  
  async getContext() {
    const agentType = process.env.AGENT_TYPE || 'psypi';
    const sessionId = process.env.AGENT_SESSION_ID || 'unknown';
    
    const tasks = await this.query("SELECT COUNT(*) as count FROM tasks WHERE status = 'PENDING'");
    const issues = await this.query("SELECT COUNT(*) as count FROM issues WHERE status = 'open'");
    
    return {
      agentType,
      sessionId,
      pendingTasks: parseInt(tasks.rows[0].count),
      openIssues: parseInt(issues.rows[0].count),
    };
  }
  
  async close() {
    await this.pool.end();
  }
}

// Export singleton
export const kernel = new Kernel();
