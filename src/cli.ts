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
program
  .command('task-add <title>')
  .description('Add a task')
  .option('--description <desc>', 'Task description')
  .option('--priority <n>', 'Priority (1-10)', '5')
  .action(async (title, options) => {
    console.log(`Task add: ${title} (priority: ${options.priority})`);
    // TODO: Integrate Nezha kernel
  });

program
  .command('tasks')
  .description('List tasks')
  .option('--status <status>', 'Filter by status')
  .action(async (options) => {
    console.log('Listing tasks...');
    // TODO: Integrate Nezha kernel
  });

program
  .command('issue-add <title>')
  .description('Add an issue')
  .option('--severity <level>', 'Severity: critical|high|medium|low', 'medium')
  .option('--tag <tags>', 'Comma-separated tags')
  .action(async (title, options) => {
    console.log(`Issue add: ${title} (severity: ${options.severity})`);
    // TODO: Integrate Nezha kernel
  });

program
  .command('issues')
  .description('List issues')
  .option('--status <status>', 'Filter by status')
  .action(async (options) => {
    console.log('Listing issues...');
    // TODO: Integrate Nezha kernel
  });

// === Agent Commands (from NuPI) ===
program
  .command('session-start')
  .description('Start a new agent session')
  .action(async () => {
    console.log('Starting agent session...');
    // TODO: Integrate NuPI agent
  });

program
  .command('session-end')
  .description('End current agent session')
  .action(async () => {
    console.log('Ending agent session...');
    // TODO: Integrate NuPI agent
  });

// === Skill Commands (from Nezha) ===
program
  .command('skill-list')
  .description('List all approved skills')
  .action(async () => {
    console.log('Listing skills...');
    // TODO: Integrate Nezha skill system
  });

program
  .command('skill-show <name>')
  .description('Show skill details')
  .action(async (name) => {
    console.log(`Showing skill: ${name}`);
    // TODO: Integrate Nezha skill system
  });

program
  .command('skill-build <name> <purpose>')
  .description('Build new skill')
  .action(async (name, purpose) => {
    console.log(`Building skill: ${name} (purpose: ${purpose})`);
    // TODO: Integrate Nezha skill system
  });

// === All-in-One Commands ===
program
  .command('reflect <text>')
  .description('All-in-one reflection: [LEARN] [ISSUE] [TASK]')
  .action(async (text) => {
    console.log(`Reflecting: ${text}`);
    // TODO: Integrate Nezha reflection system
  });

program
  .command('context')
  .description('Show current context from Nezha')
  .action(async () => {
    console.log('Showing context...');
    // TODO: Integrate Nezha context system
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
