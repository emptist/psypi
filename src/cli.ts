#!/usr/bin/env node
// Psypi CLI - Unified AI coordination system (Nezha kernel + NuPI agent)

import { Command } from 'commander';
import { config } from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load .env from psypi installation directory
const psypiRoot = dirname(fileURLToPath(import.meta.url));
config({ path: join(psypiRoot, '..', '..', '.env'), quiet: true });

// Also load from user config directory
const homeDir = process.env.HOME || process.env.USERPROFILE || '';
const userConfigPaths = [
  join(homeDir, '.config', 'psypi', '.env'),
  join(homeDir, '.psypi', '.env'),
];
for (const configPath of userConfigPaths) {
  config({ path: configPath, quiet: true });
}

const program = new Command();
const VERSION = '0.1.0';

program
  .name('psypi')
  .description('Unified AI coordination system - Nezha kernel + NuPI agent')
  .version(VERSION);

// === Kernel Commands (from Nezha) ===
import { kernel } from './kernel/index.js';

program
  .command('task-add <title>')
  .description('Add a task')
  .option('--description <desc>', 'Task description')
  .option('--priority <n>', 'Priority (1-10)', '5')
  .action(async (title, options) => {
    try {
      const taskId = await kernel.addTask(title, options.description || '', parseInt(options.priority));
      console.log(`Created task: ${taskId}`);
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

program
  .command('tasks')
  .description('List tasks')
  .option('--status <status>', 'Filter by status')
  .action(async (options) => {
    try {
      const result = await kernel.getTasks(options.status);
      if (result.rows.length === 0) {
        console.log('No tasks found.');
        return;
      }
      console.log(`\n📋 Tasks (${result.rows.length}):\n`);
      for (const task of result.rows) {
        console.log(`  [${task.id.slice(0,8)}] ${task.title}`);
        console.log(`    Status: ${task.status} | Priority: ${task.priority} | Created by: ${task.created_by}`);
      }
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

program
  .command('issue-add <title>')
  .description('Add an issue')
  .option('--severity <level>', 'Severity: critical|high|medium|low', 'medium')
  .option('--tag <tags>', 'Comma-separated tags')
  .action(async (title, options) => {
    try {
      const issueId = await kernel.addIssue(title, options.severity);
      console.log(`Created issue: ${issueId}`);
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

program
  .command('issues')
  .description('List issues')
  .option('--status <status>', 'Filter by status')
  .action(async (options) => {
    try {
      const result = await kernel.getIssues(options.status);
      if (result.rows.length === 0) {
        console.log('No issues found.');
        return;
      }
      console.log(`\n📋 Issues (${result.rows.length}):\n`);
      for (const issue of result.rows) {
        console.log(`  [${issue.id.slice(0,8)}] ${issue.title}`);
        console.log(`    Severity: ${issue.severity} | Status: ${issue.status} | Created by: ${issue.created_by}`);
      }
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

// === Agent Commands (from NuPI) ===
program
  .command('session-start')
  .description('Start a new agent session')
  .action(async () => {
    try {
      const sessionId = await kernel.startSession('psypi');
      console.log(`✅ Session started: ${sessionId}`);
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

program
  .command('session-end')
  .description('End current agent session')
  .action(async () => {
    try {
      await kernel.endSession();
      console.log('✅ Session ended');
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

// === Skill Commands (from Nezha) ===
program
  .command('skill-list')
  .description('List all approved skills')
  .action(async () => {
    try {
      const result = await kernel.getSkills(true);
      if (result.rows.length === 0) {
        console.log('No skills found.');
        return;
      }
      console.log(`\n📦 Skills (${result.rows.length}):\n`);
      for (const skill of result.rows) {
        console.log(`  🟢 ${skill.name}`);
        console.log(`     Status: ${skill.status} | Safety: ${skill.safety_score}`);
      }
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

program
  .command('skill-show <name>')
  .description('Show skill details')
  .action(async (name) => {
    try {
      const skill = await kernel.getSkillByName(name);
      if (!skill) {
        console.log(`Skill not found: ${name}`);
        return;
      }
      console.log(`\n📦 Skill: ${skill.name}`);
      console.log('='.repeat(50));
      console.log(`Description: ${skill.description || 'N/A'}`);
      console.log(`Status: ${skill.status} | Safety Score: ${skill.safety_score}`);
      if (skill.instructions) {
        console.log(`\nInstructions:\n${skill.instructions.substring(0, 200)}...`);
      }
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

program
  .command('skill-build <name> <purpose>')
  .description('Build new skill')
  .action(async (name, purpose) => {
    try {
      const skillId = await kernel.buildSkill(name, purpose);
      console.log(`✅ Skill built: ${skillId}`);
      console.log('Note: Skill created with status=pending, safety_score=0');
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

// === All-in-One Commands ===
program
  .command('areflect <text>')
  .description('All-in-one reflection: [LEARN] [ISSUE] [TASK]')
  .action(async (text) => {
    try {
      const result = await kernel.reflect(text);
      console.log(result);
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

program
  .command('context')
  .description('Show current context from Nezha')
  .action(async () => {
    try {
      const context = await kernel.getContext();
      console.log('\n📊 PSYPI CONTEXT\n');
      console.log(`🤖 Agent: ${context.agentType}`);
      console.log(`Session: ${context.sessionId}`);
      console.log(`Tasks: ${context.pendingTasks} pending`);
      console.log(`Issues: ${context.openIssues} open`);
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

// === Help ===
program
  .command('help [command]')
  .description('Show help for command')
  .action((command) => {
    if (command) {
      program.commands.find(cmd => cmd.name() === command)?.help();
    } else {
      program.help();
    }
  });

// Parse arguments
program.parse(process.argv);

// Show help if no command provided
if (!process.argv.slice(2).length) {
  program.help();
}
