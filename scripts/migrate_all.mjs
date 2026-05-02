#!/usr/bin/env node
/**
 * Full Migration Script: nezha -> psypi
 * Handles proper migration order with foreign key constraints
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

async function migrate() {
  const nezhaClient = new Client(nezhaConfig);
  const psypiClient = new Client(psypiConfig);

  try {
    await nezhaClient.connect();
    await psypiClient.connect();

    console.log('Connected to both databases');

    // Step 1: Migrate projects (psypi project only)
    console.log('\n=== Step 1: Migrating psypi project ===');
    await migrateProjects(nezhaClient, psypiClient);

    // Step 2: Migrate skills
    console.log('\n=== Step 2: Migrating skills ===');
    await migrateSkills(nezhaClient, psypiClient);

    // Step 3: Verify migration
    console.log('\n=== Verification ===');
    await verifyMigration(psypiClient);

  } catch (err) {
    console.error('Migration failed:', err);
    throw err;
  } finally {
    await nezhaClient.end();
    await psypiClient.end();
  }
}

async function migrateProjects(nezhaClient, psypiClient) {
  // Check if project already exists
  const checkResult = await psypiClient.query(
    'SELECT COUNT(*) FROM projects WHERE id = $1',
    [PSYPI_PROJECT_ID]
  );

  if (parseInt(checkResult.rows[0].count) > 0) {
    console.log('Psypi project already exists in psypi database');
    return;
  }

  // Fetch psypi project from nezha
  const projectResult = await nezhaClient.query(
    'SELECT * FROM projects WHERE id = $1',
    [PSYPI_PROJECT_ID]
  );

  if (projectResult.rows.length === 0) {
    console.log('Warning: Psypi project not found in nezha database');
    return;
  }

  const project = projectResult.rows[0];

  // Insert project into psypi
  const query = `
    INSERT INTO projects (
      id, name, description, path, language, framework, config, status,
      created_at, updated_at, last_qc_at
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8,
      $9, $10, $11
    )
    ON CONFLICT (id) DO NOTHING
  `;  
  
  await psypiClient.query(query, [
    project.id,
    project.name,
    project.description,
    project.path,
    project.language,
    project.framework,
    project.config || {},
    project.status,
    project.created_at,
    project.updated_at,
    project.last_qc_at
  ]);

  console.log(`Migrated project: ${project.name} (${project.id})`);
}

async function migrateSkills(nezhaClient, psypiClient) {
  // Check current count
  const countResult = await psypiClient.query('SELECT COUNT(*) FROM skills');
  const currentCount = parseInt(countResult.rows[0].count);

  if (currentCount > 0) {
    console.log(`Skills table already has ${currentCount} records. Clearing and re-migrating...`);
    await psypiClient.query('DELETE FROM skills');
  }

  // Fetch all skills from nezha
  console.log('Fetching skills from nezha...');
  const skillsResult = await nezhaClient.query('SELECT * FROM skills');
  console.log(`Found ${skillsResult.rows.length} skills`);

  let migrated = 0;
  let skipped = 0;

  for (const skill of skillsResult.rows) {
    try {
      // Convert project_id from text to uuid if valid
      let projectId = null;
      const projectIdText = skill.project_id;

      // Check if it's a valid UUID
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

      if (projectIdText && uuidRegex.test(projectIdText)) {
        // Valid UUID - check if this project exists in psypi
        const projectCheck = await psypiClient.query(
          'SELECT COUNT(*) FROM projects WHERE id = $1',
          [projectIdText]
        );

        if (parseInt(projectCheck.rows[0].count) > 0) {
          projectId = projectIdText;
        }
      }
      // If not valid UUID or project doesn't exist, set to null

      const allowedProjects = projectId ? [projectId] : [];

      // Handle manifest conversion
      let manifest = {};
      if (skill.manifest) {
        if (typeof skill.manifest === 'string' && skill.manifest.trim()) {
          try {
            manifest = JSON.parse(skill.manifest);
          } catch {
            manifest = { content: skill.manifest };
          }
        } else if (typeof skill.manifest === 'object' && skill.manifest !== null) {
          manifest = skill.manifest;
        }
      }

      const query = `
        INSERT INTO skills (
          id, name, description, version, category, content, tags,
          project_id, source, author, created_at, updated_at,
          builder, maintainer, build_metadata, generation_prompt,
          trigger_phrases, anti_patterns, quick_start, examples,
          safety_score, status, rating, instructions,
          manifest, external_id, scan_status, verified,
          permissions, is_enabled, use_count, last_used_at, installed_at, viewers,
          allowed_projects
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7,
          $8, $9, $10, $11, $12,
          $13, $14, $15, $16,
          $17, $18, $19, $20,
          $21, $22, $23, $24,
          $25, $26, $27, $28,
          $29, $30, $31, $32, $33, $34,
          $35
        )
        ON CONFLICT (id) DO NOTHING
      `;

      const values = [
        skill.id,
        skill.name,
        skill.description || null,
        skill.version || '1.0.0',
        skill.category || null,
        skill.content || {},
        skill.tags || [],
        projectId, // Can be null if project doesn't exist
        skill.source || 'clawhub',
        skill.author || null,
        skill.created_at || new Date(),
        skill.updated_at || new Date(),
        skill.builder || null,
        skill.maintainer || null,
        skill.build_metadata || {},
        skill.generation_prompt || null,
        skill.trigger_phrases || [],
        skill.anti_patterns || [],
        skill.quick_start || null,
        skill.examples || [],
        skill.safety_score || 0,
        skill.status || 'pending',
        skill.rating || 0,
        skill.instructions || null,
        manifest,
        skill.external_id || null,
        skill.scan_status || 'pending',
        skill.verified || false,
        skill.permissions || [],
        skill.is_enabled !== false,
        skill.use_count || 0,
        skill.last_used_at || null,
        skill.installed_at || null,
        skill.viewers || [],
        allowedProjects
      ];

      await psypiClient.query(query, values);
      migrated++;

      if (migrated % 100 === 0) {
        console.log(`Migrated ${migrated}/${skillsResult.rows.length} skills...`);
      }

    } catch (err) {
      console.error(`Error migrating skill ${skill.name}:`, err.message);
      skipped++;
    }
  }

  console.log(`\nSkills migration completed:`);
  console.log(`  - Migrated: ${migrated} skills`);
  console.log(`  - Skipped: ${skipped} skills`);
}

async function verifyMigration(psypiClient) {
  const tables = [
    'projects',
    'skills',
    'tasks',
    'issues',
    'memory',
    'agent_identities'
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

migrate().catch(console.error);
