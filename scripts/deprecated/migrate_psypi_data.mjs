#!/usr/bin/env node
/**
 * Migration Script: Psypi-specific data
 * Migrates tasks, issues, memory, meetings, etc. for psypi project
 */

import pg from 'pg';
const { Client } = pg;

const nezhaConfig = {
  host: 'localhost',
  port: 5432,
  database: 'nezha',
  user: 'postgres',
  password: 'postgres'
};

const psypiConfig = {
  host: 'localhost',
  port: 5432,
  database: 'psypi',
  user: 'postgres',
  password: 'postgres'
};

const PSYPI_PROJECT_ID = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

async function migratePsypiData() {
  const nezhaClient = new Client(nezhaConfig);
  const psypiClient = new Client(psypiConfig);
  
  try {
    await nezhaClient.connect();
    await psypiClient.connect();
    
    console.log('Connected to both databases');
    console.log(`Migrating data for psypi project: ${PSYPI_PROJECT_ID}`);
    
    // Migrate in order respecting foreign keys
    await migrateTasks(nezhaClient, psypiClient);
    await migrateIssues(nezhaClient, psypiClient);
    await migrateMemory(nezhaClient, psypiClient);
    await migrateMeetings(nezhaClient, psypiClient);
    await migrateAgentIdentities(nezhaClient, psypiClient);
    await migrateConversations(nezhaClient, psypiClient);
    await migrateProjectVisits(nezhaClient, psypiClient);
    await migrateProjectDocs(nezhaClient, psypiClient);
    await migrateProjectMetrics(nezhaClient, psypiClient);
    
    // Verify final counts
    console.log('\n=== Final Verification ===');
    await verifyAll(psypiClient);
    
  } catch (err) {
    console.error('Migration failed:', err);
    throw err;
  } finally {
    await nezhaClient.end();
    await psypiClient.end();
  }
}

async function migrateTasks(nezhaClient, psypiClient) {
  console.log('\n=== Migrating Tasks ===');
  
  const result = await nezhaClient.query(
    'SELECT * FROM tasks WHERE project_id = $1',
    [PSYPI_PROJECT_ID]
  );
  
  console.log(`Found ${result.rows.length} tasks for psypi project`);
  
  let migrated = 0;
  for (const task of result.rows) {
    try {
      const query = `
        INSERT INTO tasks (
          id, project_id, title, description, status, priority, type,
          created_by, assigned_to,
          depends_on, 
          created_at, updated_at, started_at, completed_at,
          timeout_seconds, tags, category,
          metadata, result, retry_count, max_retries
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7,
          $8, $9,
          COALESCE($10, '{}'::uuid[]), 
          $11, $12, $13, $14,
          $15, $16, $17,
          $18, $19, $20, $21
        ) ON CONFLICT (id) DO NOTHING
      `;
      
      await psypiClient.query(query, [
        task.id,
        task.project_id,
        task.title,
        task.description,
        task.status,
        task.priority,
        task.type,
        task.created_by,
        task.assigned_to,
        task.depends_on,
        task.created_at,
        task.updated_at,
        task.started_at,
        task.completed_at,
        task.timeout_seconds,
        task.tags || [],
        task.category,
        task.metadata || {},
        task.result,
        task.retry_count || 0,
        task.max_retries || 3
      ]);
      
      migrated++;
    } catch (err) {
      console.error(`Error migrating task ${task.title}:`, err.message);
    }
  }
  
  console.log(`Migrated ${migrated} tasks`);
}

async function migrateIssues(nezhaClient, psypiClient) {
  console.log('\n=== Migrating Issues ===');
  
  // In psypi, issues are linked via task_id, not project_id
  // Get issues linked to psypi tasks
  const result = await nezhaClient.query(`
    SELECT i.* FROM issues i
    JOIN tasks t ON i.task_id = t.id
    WHERE t.project_id = $1
    UNION
    SELECT i.* FROM issues i
    WHERE i.discovered_by = 'psypi'
  `, [PSYPI_PROJECT_ID]);
  
  console.log(`Found ${result.rows.length} issues for psypi project`);
  
  let migrated = 0;
    for (const issue of result.rows) {
    try {
      const query = `
        INSERT INTO issues (
          id, title, description, issue_type, severity,
          discovered_by, discovered_at, 
          related_issue_id, task_id, resolution, resolved_at,
          resolved_by, tags, metadata, created_at, updated_at,
          assignee, assignee_type, review_id, dlq_id, viewers
        ) VALUES (
          $1, $2, $3, $4, $5,
          $6, $7, 
          $8, $9, $10, $11,
          $12, $13, $14, $15, $16,
          $17, $18, $19, $20, $21
        ) ON CONFLICT (id) DO NOTHING
      `;
      
      await psypiClient.query(query, [
        issue.id,
        issue.title,
        issue.description,
        issue.issue_type || issue.type,  // handle both schemas
        issue.severity,
        issue.discovered_by,
        issue.discovered_at,
        issue.related_issue_id,
        issue.task_id,
        issue.resolution,
        issue.resolved_at,
        issue.resolved_by,
        issue.tags || [],
        issue.metadata || {},
        issue.created_at,
        issue.updated_at,
        issue.assignee,
        issue.assignee_type,
        issue.review_id,
        issue.dlq_id,
        issue.viewers || []
      ]);
      
      migrated++;
    } catch (err) {
      console.error(`Error migrating issue ${issue.title}:`, err.message);
    }
  }
  
  console.log(`Migrated ${migrated} issues`);
}

async function migrateMemory(nezhaClient, psypiClient) {
  console.log('\n=== Migrating Memory ===');
  
  const result = await nezhaClient.query(
    'SELECT * FROM memory WHERE project_id = $1',
    [PSYPI_PROJECT_ID]
  );
  
  console.log(`Found ${result.rows.length} memory records for psypi project`);
  
  let migrated = 0;
  for (const mem of result.rows) {
    try {
      const query = `
        INSERT INTO memory (
          id, project_id, content, tags, importance,
          created_at, updated_at, embedding
        ) VALUES (
          $1, $2, $3, $4, $5,
          $6, $7, $8
        ) ON CONFLICT (id) DO NOTHING
      `;
      
      await psypiClient.query(query, [
        mem.id,
        mem.project_id,
        mem.content,
        mem.tags || [],
        mem.importance || 5,
        mem.created_at,
        mem.updated_at,
        mem.embedding
      ]);
      
      migrated++;
    } catch (err) {
      console.error(`Error migrating memory ${mem.id}:`, err.message);
    }
  }
  
  console.log(`Migrated ${migrated} memory records`);
}

async function migrateMeetings(nezhaClient, psypiClient) {
  console.log('\n=== Migrating Meetings ===');
  console.log('Skipping meetings migration (not project-specific, status constraint issues)');
  return;
}

async function migrateAgentIdentities(nezhaClient, psypiClient) {
  console.log('\n=== Migrating Agent Identities ===');
  
  // agent_identities uses 'project' column (varchar) with project name
  const result = await nezhaClient.query(
    "SELECT * FROM agent_identities WHERE project = 'psypi'"
  );
  
  console.log(`Found ${result.rows.length} agent identities for psypi project`);
  
  let migrated = 0;
  for (const agent of result.rows) {
    try {
      const query = `
        INSERT INTO agent_identities (
          id, project, git_hash, machine_fingerprint,
          created_at, updated_at, display_name, description, owner
        ) VALUES (
          $1, $2, $3, $4,
          $5, $6, $7, $8, $9
        ) ON CONFLICT (id) DO NOTHING
      `;
      
      await psypiClient.query(query, [
        agent.id,
        agent.project,
        agent.git_hash,
        agent.machine_fingerprint,
        agent.created_at,
        agent.updated_at,
        agent.display_name,
        agent.description,
        agent.owner
      ]);
      
      migrated++;
    } catch (err) {
      console.error(`Error migrating agent identity ${agent.name}:`, err.message);
    }
  }
  
  console.log(`Migrated ${migrated} agent identities`);
}

async function migrateConversations(nezhaClient, psypiClient) {
  console.log('\n=== Migrating Conversations ===');
  
  const result = await nezhaClient.query(
    'SELECT * FROM conversations WHERE project_id = $1',
    [PSYPI_PROJECT_ID]
  );
  
  console.log(`Found ${result.rows.length} conversations for psypi project`);
  
  let migrated = 0;
  for (const conv of result.rows) {
    try {
      const query = `
        INSERT INTO conversations (
          id, project_id, title, messages, model,
          created_at, updated_at, metadata
        ) VALUES (
          $1, $2, $3, $4, $5,
          $6, $7, $8
        ) ON CONFLICT (id) DO NOTHING
      `;
      
      await psypiClient.query(query, [
        conv.id,
        conv.project_id,
        conv.title,
        conv.messages || [],
        conv.model,
        conv.created_at,
        conv.updated_at,
        conv.metadata || {}
      ]);
      
      migrated++;
    } catch (err) {
      console.error(`Error migrating conversation ${conv.id}:`, err.message);
    }
  }
  
  console.log(`Migrated ${migrated} conversations`);
}

async function migrateProjectVisits(nezhaClient, psypiClient) {
  console.log('\n=== Migrating Project Visits ===');
  
  const result = await nezhaClient.query(
    'SELECT * FROM project_visits WHERE project_id = $1',
    [PSYPI_PROJECT_ID]
  );
  
  console.log(`Found ${result.rows.length} project visits for psypi project`);
  
  if (result.rows.length === 0) return;
  
  let migrated = 0;
  for (const visit of result.rows) {
    try {
      await psypiClient.query(`
        INSERT INTO project_visits (
          id, project_id, visited_at, visitor_id, visitor_type
        ) VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (id) DO NOTHING
      `, [
        visit.id,
        visit.project_id,
        visit.visited_at,
        visit.visitor_id,
        visit.visitor_type
      ]);
      migrated++;
    } catch (err) {
      console.error(`Error migrating visit:`, err.message);
    }
  }
  
  console.log(`Migrated ${migrated} project visits`);
}

async function migrateProjectDocs(nezhaClient, psypiClient) {
  console.log('\n=== Migrating Project Docs ===');
  
  const result = await nezhaClient.query(
    'SELECT * FROM project_docs WHERE project_id = $1',
    [PSYPI_PROJECT_ID]
  );
  
  console.log(`Found ${result.rows.length} project docs for psypi project`);
  
  if (result.rows.length === 0) return;
  
  let migrated = 0;
  for (const doc of result.rows) {
    try {
      await psypiClient.query(`
        INSERT INTO project_docs (
          id, project_id, name, content, file_path,
          created_at, updated_at, priority
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (id) DO NOTHING
      `, [
        doc.id,
        doc.project_id,
        doc.name,
        doc.content,
        doc.file_path,
        doc.created_at,
        doc.updated_at,
        doc.priority || 0
      ]);
      migrated++;
    } catch (err) {
      console.error(`Error migrating doc:`, err.message);
    }
  }
  
  console.log(`Migrated ${migrated} project docs`);
}

async function migrateProjectMetrics(nezhaClient, psypiClient) {
  console.log('\n=== Migrating Project Metrics ===');
  
  const result = await nezhaClient.query(
    'SELECT * FROM project_metrics WHERE project_id = $1',
    [PSYPI_PROJECT_ID]
  );
  
  console.log(`Found ${result.rows.length} project metrics for psypi project`);
  
  if (result.rows.length === 0) return;
  
  let migrated = 0;
  for (const metric of result.rows) {
    try {
      await psypiClient.query(`
        INSERT INTO project_metrics (
          id, project_id, metric_name, metric_value, recorded_at
        ) VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (id) DO NOTHING
      `, [
        metric.id,
        metric.project_id,
        metric.metric_name,
        metric.metric_value,
        metric.recorded_at
      ]);
      migrated++;
    } catch (err) {
      console.error(`Error migrating metric:`, err.message);
    }
  }
  
  console.log(`Migrated ${migrated} project metrics`);
}

async function verifyAll(psypiClient) {
  const tables = [
    'projects',
    'skills',
    'tasks',
    'issues',
    'memory',
    'meetings',
    'meeting_opinions',
    'agent_identities',
    'conversations',
    'project_visits',
    'project_docs',
    'project_metrics'
  ];
  
  for (const table of tables) {
    try {
      const result = await psypiClient.query(`SELECT COUNT(*) FROM ${table}`);
      console.log(`  - ${table}: ${result.rows[0].count} records`);
    } catch (err) {
      console.log(`  - ${table}: error (${err.message})`);
    }
  }
}

migratePsypiData().catch(console.error);
