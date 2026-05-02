#!/usr/bin/env node
/**
 * Complete Schema Migration: nezha -> psypi
 * Creates ALL missing tables in psypi, then migrates ALL data
 */

import pg from 'pg';
import fs from 'fs';
import { execSync } from 'child_process';
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

// Tables that exist in nezha but not in psypi (from earlier diff)
const MISSING_TABLES = [
  'agent_configs',
  'agent_moods',
  'agent_soul',
  'failure_alerts',
  'heartbeat_configs',
  'knowledge_links',
  'learning_insights',
  'long_tasks_pause',
  'memories',
  'milestones',
  'priority_learnings',
  'project_communications',
  'project_config_history',
  'project_docs',
  'project_skills',
  'project_visits',
  'provider_api_keys',
  'psypi_config',
  'retry_learning',
  'retry_strategies',
  'review_comments',
  'review_labels',
  'skill_audit_log',
  'skill_builder_config',
  'skill_feedback',
  'skill_versions',
  'stuck_tasks_tracking',
  'system_reviews',
  'task_comments',
  'task_outcome_features',
  'task_patterns',
  'task_results',
  'test_uuid_col',
  'tool_definitions',
  'user_profiles'
];

async function completeSchemaMigration() {
  const nezhaClient = new Client(nezhaConfig);
  const psypiClient = new Client(psypiConfig);
  
  try {
    await nezhaClient.connect();
    await psypiClient.connect();
    
    console.log('Connected to both databases');
    console.log('Starting complete schema migration...');
    
    // Step 1: Create missing tables in psypi
    console.log('\n=== Step 1: Creating missing tables ===');
    await createMissingTables(psypiClient);
    
    // Step 2: Migrate ALL data from nezha to psypi
    console.log('\n=== Step 2: Migrating all data ===');
    await migrateAllData(nezhaClient, psypiClient);
    
    // Step 3: Verify migration
    console.log('\n=== Step 3: Verification ===');
    await verifyCompleteMigration(nezhaClient, psypiClient);
    
  } catch (err) {
    console.error('Migration failed:', err);
    throw err;
  } finally {
    await nezhaClient.end();
    await psypiClient.end();
  }
}

async function createMissingTables(psypiClient) {
  const PATH = "/Applications/Postgres.app/Contents/Versions/latest/bin";
  
  // Get schema for missing tables from nezha
  const tableList = MISSING_TABLES.join(' ');
  const dumpCmd = `${PATH}/pg_dump -U postgres -d nezha --schema-only ${tableList}`;
  
  console.log('Dumping schema for missing tables...');
  
  try {
    const schema = execSync(dumpCmd, { encoding: 'utf8' });
    
    // Save schema to temp file
    fs.writeFileSync('/tmp/missing_tables_schema.sql', schema);
    console.log(`Schema saved to /tmp/missing_tables_schema.sql (${schema.split('\n').length} lines)`);
    
    // Apply schema to psypi
    console.log('Applying schema to psypi database...');
    
    // Read and execute SQL statements
    const statements = schema.split(';').filter(s => s.trim().length > 0);
    let created = 0;
    
    for (const stmt of statements) {
      const trimmed = stmt.trim();
      if (trimmed.startsWith('--') || trimmed.length === 0) continue;
      
      try {
        // Skip ALTER TABLE ... OWNER TO statements
        if (trimmed.includes('OWNER TO')) continue;
        
        await psypiClient.query(trimmed + ';');
        created++;
      } catch (err) {
        // Ignore "already exists" errors
        if (!err.message.includes('already exists')) {
          console.error(`Error applying statement: ${err.message}`);
          console.error(`Statement: ${trimmed.substring(0, 100)}...`);
        }
      }
    }
    
    console.log(`Applied ${created} SQL statements`);
    
  } catch (err) {
    console.error('Failed to dump/apply schema:', err.message);
    throw err;
  }
}

async function migrateAllData(nezhaClient, psypiClient) {
  // Get all tables from nezha
  const tablesResult = await nezhaClient.query(`
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    ORDER BY table_name
  `);
  
  const tables = tablesResult.rows.map(r => r.table_name);
  console.log(`Found ${tables.length} tables in nezha`);
  
  let totalMigrated = 0;
  
  for (const table of tables) {
    try {
      // Check if table exists in psypi
      const existsResult = await psypiClient.query(`
        SELECT EXISTS (
          SELECT FROM information_schema.tables 
          WHERE table_schema = 'public' AND table_name = $1
        )
      `, [table]);
      
      if (!existsResult.rows[0].exists) {
        console.log(`Skipping ${table} (does not exist in psypi)`);
        continue;
      }
      
      // Get count in nezha
      const countResult = await nezhaClient.query(`SELECT COUNT(*) FROM "${table}"`);
      const count = parseInt(countResult.rows[0].count);
      
      if (count === 0) {
        console.log(`Skipping ${table} (empty)`);
        continue;
      }
      
      // Check if already migrated
      const psypiCountResult = await psypiClient.query(`SELECT COUNT(*) FROM "${table}"`);
      const psypiCount = parseInt(psypiCountResult.rows[0].count);
      
      if (psypiCount > 0) {
        console.log(`Skipping ${table} (already has ${psypiCount} records)`);
        continue;
      }
      
      // Migrate data
      console.log(`Migrating ${table} (${count} records)...`);
      
      const result = await nezhaClient.query(`SELECT * FROM "${table}"`);
      let migrated = 0;
      
      for (const row of result.rows) {
        try {
          const columns = Object.keys(row);
          const placeholders = columns.map((_, i) => `$${i + 1}`).join(', ');
          const values = Object.values(row);
          
          // Build column list with quotes
          const columnList = columns.map(c => `"${c}"`).join(', ');
          
          await psypiClient.query(`
            INSERT INTO "${table}" (${columnList}) 
            VALUES (${placeholders})
            ON CONFLICT DO NOTHING
          `, values);
          
          migrated++;
        } catch (err) {
          // Skip individual row errors (duplicate keys, etc.)
          if (!err.message.includes('duplicate key')) {
            console.error(`  Error migrating row: ${err.message}`);
          }
        }
      }
      
      console.log(`  Migrated ${migrated}/${count} records`);
      totalMigrated += migrated;
      
    } catch (err) {
      console.error(`Error processing table ${table}:`, err.message);
    }
  }
  
  console.log(`\nTotal records migrated: ${totalMigrated}`);
}

async function verifyCompleteMigration(nezhaClient, psypiClient) {
  const tablesResult = await nezhaClient.query(`
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    ORDER BY table_name
  `);
  
  console.log('\nVerification Results:');
  console.log('='.repeat(50));
  
  let allMatch = true;
  
  for (const row of tablesResult.rows) {
    const table = row.table_name;
    
    try {
      // Check if table exists in psypi
      const existsResult = await psypiClient.query(`
        SELECT EXISTS (
          SELECT FROM information_schema.tables 
          WHERE table_schema = 'public' AND table_name = $1
        )
      `, [table]);
      
      if (!existsResult.rows[0].exists) {
        console.log(`  ✗ ${table}: MISSING in psypi`);
        allMatch = false;
        continue;
      }
      
      // Compare counts
      const nezhaCount = await nezhaClient.query(`SELECT COUNT(*) FROM "${table}"`);
      const psypiCount = await psypiClient.query(`SELECT COUNT(*) FROM "${table}"`);
      
      const nCount = parseInt(nezhaCount.rows[0].count);
      const pCount = parseInt(psypiCount.rows[0].count);
      
      if (nCount === pCount) {
        console.log(`  ✓ ${table}: ${pCount} records`);
      } else {
        console.log(`  ⚠ ${table}: nezha=${nCount}, psypi=${pCount}`);
        allMatch = false;
      }
      
    } catch (err) {
      console.log(`  ? ${table}: Error - ${err.message}`);
    }
  }
  
  console.log('='.repeat(50));
  
  if (allMatch) {
    console.log('\n✅ All tables match! Migration complete.');
  } else {
    console.log('\n⚠ Some tables have differences - see above');
  }
}

completeSchemaMigration().catch(console.error);
