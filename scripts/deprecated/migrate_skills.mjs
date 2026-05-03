#!/usr/bin/env node
/**
 * Skills Migration Script: nezha -> psypi
 * Run from psypi project directory: node scripts/migrate_skills.mjs
 */

import { Client } from 'pg';

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

async function migrateSkills() {
  const nezhaClient = new Client(nezhaConfig);
  const psypiClient = new Client(psypiConfig);
  
  try {
    await nezhaClient.connect();
    await psypiClient.connect();
    
    console.log('Connected to both databases');
    
    // Check psypi skills count
    const psypiCount = await psypiClient.query('SELECT COUNT(*) FROM skills');
    const currentCount = parseInt(psypiCount.rows[0].count);
    
    if (currentCount > 0) {
      console.log(`Skills table already has ${currentCount} records. Skipping migration.`);
      return;
    }
    
    // Fetch all skills from nezha
    console.log('Fetching skills from nezha...');
    const nezhaSkills = await nezhaClient.query('SELECT * FROM skills');
    console.log(`Found ${nezhaSkills.rows.length} skills in nezha`);
    
    // Migrate each skill
    let migrated = 0;
    let skipped = 0;
    
    for (const skill of nezhaSkills.rows) {
      try {
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
        
        // Convert project_id from text to uuid if valid
        let projectId = null;
        const projectIdText = skill.project_id;
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        
        if (projectIdText && uuidRegex.test(projectIdText)) {
          projectId = projectIdText;
        }
        
        const allowedProjects = projectId ? [projectId] : [];
        
        // Handle manifest
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
        
        const values = [
          skill.id,
          skill.name,
          skill.description || null,
          skill.version || '1.0.0',
          skill.category || null,
          skill.content || {},
          skill.tags || [],
          projectId,
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
          console.log(`Migrated ${migrated}/${nezhaSkills.rows.length} skills...`);
        }
        
      } catch (err) {
        console.error(`Error migrating skill ${skill.name}:`, err.message);
        skipped++;
      }
    }
    
    console.log(`\nMigration completed:`);
    console.log(`  - Migrated: ${migrated} skills`);
    console.log(`  - Skipped: ${skipped} skills`);
    
    const verifyResult = await psypiClient.query('SELECT COUNT(*) FROM skills');
    console.log(`\nVerification: psypi.skills now has ${verifyResult.rows[0].count} records`);
    
  } catch (err) {
    console.error('Migration failed:', err);
    throw err;
  } finally {
    await nezhaClient.end();
    await psypiClient.end();
  }
}

migrateSkills().catch(console.error);
