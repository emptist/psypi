/**
 * Psypi Kernel - Integrated from Nezha
 * 
 * Provides: Database, Tasks, Memory, Skills, Issues
 * No server, no strange things - just core services
 */

import { config } from 'dotenv';
import { DatabaseClient } from './db/DatabaseClient.js';
import { Config } from './config/Config.js';
import { AgentIdentityService } from './services/AgentIdentityService.js';

// Load env
config();

export class Kernel {
  private db: DatabaseClient;
  
  constructor() {
    // Use singleton DatabaseClient
    this.db = DatabaseClient.getInstance();
  }
  
  async query(text: string, params?: any[]) {
    return this.db.query(text, params);
  }
  
  private async getAgentId(): Promise<string> {
    const identity = await AgentIdentityService.getResolvedIdentity();
    return identity.id;
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
    const agentId = await this.getAgentId();
    const result = await this.query(
      `INSERT INTO tasks (id, title, description, status, priority, category, created_by) 
       VALUES (gen_random_uuid(), $1, $2, 'PENDING', $3, 'general', $4) 
       RETURNING id`,
      [title, description, priority, agentId]
    );
    return result.rows[0].id;
  }
  
  async completeTask(taskId: string) {
    const result = await this.query(
      `UPDATE tasks SET status = 'COMPLETED', completed_at = NOW(), updated_at = NOW() 
       WHERE id = $1 AND status != 'COMPLETED'
       RETURNING id`,
      [taskId]
    );
    return (result.rowCount || 0) > 0;
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
    const agentId = await this.getAgentId();
    const result = await this.query(
      `INSERT INTO issues (id, title, severity, status, created_by) 
       VALUES (gen_random_uuid(), $1, $2, 'open', $3) 
       RETURNING id`,
      [title, severity, agentId]
    );
    return result.rows[0].id;
  }
  
  async resolveIssue(issueId: string, notes?: string) {
    const result = await this.query(
      `UPDATE issues SET status = 'resolved', updated_at = NOW() 
       WHERE id = $1 AND status != 'resolved'
       RETURNING id`,
      [issueId]
    );
    return (result.rowCount || 0) > 0;
  }
  
  // === Learning Methods ===
  async learn(content: string, importance: number = 5, tags: string[] = ['learning']) {
    const result = await this.query(
      `INSERT INTO memory (content, tags, source, importance) 
       VALUES ($1, $2, 'learn', $3)
       RETURNING id`,
      [content, tags, importance]
    );
    return result.rows[0]?.id;
  }
  
  // === Tool Discovery Methods ===
  async getTools() {
    const result = await this.query(
      `SELECT table_name, usage_context, cli_commands 
       FROM table_documentation 
       WHERE ai_can_modify = true
       ORDER BY table_name ASC`
    );
    return result.rows;
  }
  
  // === Commit Validation Methods ===
  async validateCommit(message: string): Promise<{valid: boolean; error?: string}> {
    // Check for task/issue/inter-review IDs
    const hasTask = /\[task:\s*[a-f0-9-]{36}\]/i.test(message);
    const hasIssue = /\[issue:\s*[a-f0-9-]{36}\]/i.test(message);
    const hasInterReview = /\[inter-review:\s*[a-f0-9-]{36}\]/i.test(message);
    
    if (!hasTask && !hasIssue && !hasInterReview) {
      return {
        valid: false,
        error: 'Commit message must contain at least one of: [task:], [issue:], [inter-review:]'
      };
    }
    
    // Validate task IDs exist (if any)
    const taskIds = message.match(/\[task:\s*([a-f0-9-]{36})\]/gi) || [];
    for (const match of taskIds) {
      const id = match.match(/[a-f0-9-]{36}/)?.[0];
      if (id) {
        const result = await this.query('SELECT id FROM tasks WHERE id = $1', [id]);
        if (result.rowCount === 0) {
          return { valid: false, error: `Task ID not found: ${id}` };
        }
      }
    }
    
    return { valid: true };
  }
  
  // === Git Hooks Setup Methods ===
  async setupHooks(projectRoot: string = process.cwd()): Promise<{success: boolean; message: string}> {
    try {
      const path = await import('path');
      const fs = await import('fs');
      
      const gitHooksDir = path.join(projectRoot, '.git', 'hooks');
      if (!fs.existsSync(gitHooksDir)) {
        return { success: false, message: '.git/hooks directory not found' };
      }
      
      // Create prepare-commit-msg hook
      const prepareCommitMsg = `#!/bin/sh
# psypi prepare-commit-msg hook
# Auto-generated by: psypi setup-hooks

COMMIT_MSG_FILE="$1"

if [ ! -f "$COMMIT_MSG_FILE" ]; then
    exit 0
fi

# Check for task/issue ID
if ! grep -qE '\[(task|issue):' "$COMMIT_MSG_FILE" 2>/dev/null; then
    echo ""
    echo "=========================================="
    echo " COMMIT BLOCKED - Quality Control Check"
    echo "=========================================="
    echo ""
    echo "Your commit message must contain a task or issue ID."
    echo "Example: git commit -m 'Fix bug [task: 43b880df-9d65-48b2-8747-495f310010c3]''
    echo ""
    exit 1
fi

exit 0
`;
      
      const hooks = [
        { name: 'prepare-commit-msg', content: prepareCommitMsg },
        { name: 'post-commit', content: `#!/bin/sh
# psypi post-commit hook
# Auto-generated by: psypi setup-hooks

COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null)
COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null)

# Mark tasks complete from commit message
TASK_IDS=$(echo "$COMMIT_MSG" | grep -oE '\[task:\s*[a-f0-9-]+\]' | grep -oE '[a-f0-9-]+' | sort -u)
if [ -n "$TASK_IDS" ]; then
    for TASK_ID in $TASK_IDS; do
        psypi task-complete $TASK_ID 2>/dev/null || true
        echo "[post-commit] Marked task $TASK_ID as COMPLETED"
    done
fi

exit 0
` }
      ];
      
      for (const hook of hooks) {
        const hookPath = path.join(gitHooksDir, hook.name);
        fs.writeFileSync(hookPath, hook.content);
        fs.chmodSync(hookPath, '755');
      }
      
      return { success: true, message: 'Git hooks installed successfully' };
    } catch (err) {
      return { success: false, message: `Error: ${err instanceof Error ? err.message : err}` };
    }
  }
  
  // === Task Completion by Commit Methods ===
  async completeTasksByMessage(message: string): Promise<{completed: number; total: number}> {
    const taskIds = message.match(/\[task:\s*([a-f0-9-]+)\]/gi) || [];
    const uniqueIds = [...new Set(taskIds.map(m => m.match(/[a-f0-9-]{36}/)?.[0]).filter((id): id is string => !!id))];
    
    let completed = 0;
    for (const id of uniqueIds) {
      const result = await this.completeTask(id);
      if (result) completed++;
    }
    
    return { completed, total: uniqueIds.length };
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
  
  async areflect(text: string) {
    const results: string[] = [];
    const agentId = await this.getAgentId();
    
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
         VALUES (gen_random_uuid(), $1, 'open', $2) RETURNING id`,
        [title, agentId]
      );
      results.push(`✅ Issue created: ${result.rows[0].id}`);
    }
    
    // Handle [ISSUE_COMMENT] marker
    const commentMatch = text.match(/\[ISSUE_COMMENT\]\s*id:\s*([a-f0-9-]+)\s+comment:\s*(.+?)(?=\s*\[|$)/i);
    if (commentMatch) {
      const issueId = commentMatch[1].trim();
      const comment = commentMatch[2].trim();
      const issueResult = await this.query(`SELECT title FROM issues WHERE id = $1`, [issueId]);
      if (issueResult.rows.length === 0) {
        results.push(`Issue not found: ${issueId}`);
      } else {
        await this.query(
          `INSERT INTO issue_comments (issue_id, author, content) VALUES ($1, $2, $3)`,
          [issueId, agentId, comment]
        );
        results.push(`✅ Commented on issue: ${issueResult.rows[0].title.substring(0, 50)}...`);
      }
    }
    
    // Handle [ISSUE_RESOLVE] marker
    const resolveMatch = text.match(/\[ISSUE_RESOLVE\]\s*id:\s*([a-f0-9-]+)\s+resolution:\s*(.+?)(?=\s*\[|$)/i);
    if (resolveMatch) {
      const issueId = resolveMatch[1].trim();
      const resolution = resolveMatch[2].trim();
      await this.query(
        `UPDATE issues SET status = 'resolved', resolution = $1, resolved_at = NOW(), resolved_by = $2 WHERE id = $3`,
        [resolution, agentId, issueId]
      );
      results.push(`✅ Issue resolved: ${issueId.slice(0, 8)}`);
    }
    
    // Handle [TASK_COMPLETE] marker
    const completeMatch = text.match(/\[TASK_COMPLETE\]\s*id:\s*([a-f0-9-]+)(?:\s+result:\s*(.+?))?(?=\s*\[|$)/i);
    if (completeMatch) {
      const taskId = completeMatch[1].trim();
      const result = completeMatch[2]?.trim() || 'Completed via areflect';
      await this.query(
        `UPDATE tasks SET status = 'COMPLETED', result = $1, completed_at = NOW() WHERE id = $2`,
        [result, taskId]
      );
      results.push(`✅ Task completed: ${taskId.slice(0, 8)}`);
    }
    
    // Simple check for [TASK] marker
    if (text.includes('[TASK]')) {
      const title = text.replace('[TASK]', '').trim();
      const result = await this.query(
        `INSERT INTO tasks (id, title, status, priority, category, created_by) 
         VALUES (gen_random_uuid(), $1, 'PENDING', 5, 'general', $2) RETURNING id`,
        [title, agentId]
      );
      results.push(`✅ Task created: ${result.rows[0].id}`);
    }
    
    return results.join('\n');
  }
  
  async buildSkill(name: string, purpose: string) {
    const agentId = await this.getAgentId();
    // Simple skill build - insert into skills table
    const result = await this.query(
      `INSERT INTO skills (id, name, description, status, safety_score, created_by) 
       VALUES (gen_random_uuid(), $1, $2, 'pending', 0, $3) 
       RETURNING id`,
      [name, purpose, agentId]
    );
    return result.rows[0].id;
  }
  
  // === Session ID (Single Source of Truth) ===
  /**
   * Get current Pi Session ID (UUID v7)
   * This is the ONLY way to get session ID in psypi.
   * @throws Error if AGENT_SESSION_ID is not set (Pi TUI not running)
   */
  async piSessionID(): Promise<string> {
    const sessionID = process.env.AGENT_SESSION_ID;
    if (!sessionID) {
      throw new Error('AGENT_SESSION_ID not set. Pi TUI must be running.');
    }
    return sessionID;
  }
  
  // === Inter-Review Methods (from Nezha) ===
  private interReviewService: any = null;
  private contextBuilder: any = null;
  
  async getInterReviewService() {
    if (!this.interReviewService) {
      // Dynamic import to avoid circular dependencies
      const { InterReviewService } = await import('./services/InterReviewService.js');
      this.interReviewService = await InterReviewService.create(this.db);
    }
    return this.interReviewService;
  }
  
  async requestReview(taskId: string, reviewerAgentId?: string) {
    const service = await this.getInterReviewService();
    const identity = await AgentIdentityService.getResolvedIdentity();
    const reviewerId = reviewerAgentId || identity.id;
    
    // Resolve short task ID to full UUID
    const { resolveTaskId } = await import('./utils/resolve-id.js');
    const resolvedTaskId = await resolveTaskId(this.db, taskId);
    
    return service.requestReview({
      taskId: resolvedTaskId || undefined,
      reviewerId,
      context: {},
    });
  }
  
  async getReview(reviewId: string) {
    const service = await this.getInterReviewService();
    return service.getReview(reviewId);
  }
  
  async listReviews(status?: string) {
    const service = await this.getInterReviewService();
    return service.listReviews(status);
  }
  
  // === Announce/Broadcast Methods ===
  private broadcastService: any = null;
  
  async getBroadcastService() {
    if (!this.broadcastService) {
      const { BroadcastService } = await import('./services/BroadcastService.js');
      this.broadcastService = await BroadcastService.create(this.db);
    }
    return this.broadcastService;
  }
  
  async announce(message: string, priority: string = 'normal') {
    try {
      const svc = await this.getBroadcastService();
      const id = await svc.sendBroadcast(message, { priority });
      return id;
    } catch (err) {
      console.error('Announce error:', err);
      return null;
    }
  }
  
  async close() {
    await this.db.close();
  }
}

// Export singleton
export const kernel = new Kernel();
