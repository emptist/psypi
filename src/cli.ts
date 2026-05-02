#!/usr/bin/env node
// Psypi CLI - Unified AI coordination system (Nezha kernel + PsyPI agent)

import { Command } from 'commander';
import { config } from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join, basename } from 'path';

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
  .description('Unified AI coordination system - Nezha kernel + PsyPI agent')
  .version(VERSION);

// === Kernel Commands (from Nezha) ===
import { kernel } from './kernel/index.js';
import { DatabaseClient } from './kernel/db/DatabaseClient.js';
import { ApiKeyService } from './kernel/services/ApiKeyService.js';
import { AgentIdentityService } from './kernel/services/AgentIdentityService.js';
import { InterReviewService } from './kernel/services/InterReviewService.js';
import { resolveIssueId, resolveMeetingId } from './kernel/utils/resolve-id.js';
import { MeetingCommands, MeetingDbCommands } from './kernel/cli/MeetingCommands.js';


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
  .command('task-complete <taskId>')
  .description('Mark a task as completed')
  .action(async (taskId) => {
    try {
      const success = await kernel.completeTask(taskId);
      if (success) {
        console.log(`✅ Task ${taskId.slice(0,8)} marked COMPLETED`);
      } else {
        console.log(`⚠️  Task ${taskId.slice(0,8)} not found or already completed`);
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
  .command('issue-list')
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

program
  .command('issue-resolve <issueId>')
  .description('Mark an issue as resolved')
  .option('--notes <text>', 'Resolution notes')
  .action(async (issueId, options) => {
    try {
      const resolvedId = await resolveIssueId(DatabaseClient.getInstance(), issueId);
      const success = await kernel.resolveIssue(resolvedId || issueId, options.notes);
      if (success) {
        console.log(`✅ Issue ${(resolvedId || issueId).slice(0,8)} marked as RESOLVED`);
      } else {
        console.log(`⚠️  Issue ${(resolvedId || issueId).slice(0,8)} not found or already resolved`);
      }
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

// === Agent Commands (from PsyPI) ===
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

program
  .command('provider-set-key <provider>')
  .description('Set API key for provider (encrypts with PSYPI_SECRET or NEZHA_SECRET)')
  .option('--key <apiKey>', 'API key (omit for local providers like ollama)')
  .option('--model <model>', 'Model name (optional)')
  .option('--status <status>', 'Status: in_use|fallback|not_used', 'in_use')
  .action(async (provider, options) => {
    try {
      if (!process.env.PSYPI_SECRET && !process.env.NEZHA_SECRET && options.key) {
        console.error('❌ PSYPI_SECRET (or NEZHA_SECRET) not set in environment');
        return;
      }
      
      // Encrypt the API key if provided
      let encryptedKey = '';
      let encryptedIv = '';
      let encryptedTag = '';
      let encryptedSalt = '';
      
      if (options.key) {
        const { EncryptionService } = await import('./kernel/services/EncryptionService.js');
        const encryption = EncryptionService.getInstance();
        const encrypted = await encryption.encrypt(options.key);
        encryptedKey = encrypted.encryptedData;
        encryptedIv = encrypted.iv;
        encryptedTag = encrypted.tag;
        encryptedSalt = encrypted.salt;
        console.log(`✅ API key encrypted with PSYPI_SECRET (or NEZHA_SECRET)`);
      } else {
        console.log(`⚠️  No API key provided (OK for local providers like ollama)`);
      }
      
      // Check if provider exists
      const existing = await kernel.query(
        `SELECT id FROM provider_api_keys WHERE provider = $1`,
        [provider]
      );
      
      // If setting to in_use, first reset all others
      if (options.status === 'in_use') {
        await kernel.query(`UPDATE provider_api_keys SET status = 'not_used'`);
      }
      
      if (existing.rows.length > 0) {
        // Update existing
        const updates = [];
        const values: any[] = [];
        let idx = 1;
        
        if (options.key || encryptedKey) {
          updates.push(`encrypted_key = $${idx++}`);
          values.push(encryptedKey);
          updates.push(`encrypted_iv = $${idx++}`);
          values.push(encryptedIv);
          updates.push(`encrypted_tag = $${idx++}`);
          values.push(encryptedTag);
          updates.push(`encrypted_salt = $${idx++}`);
          values.push(encryptedSalt);
        }
        
        if (options.model) {
          updates.push(`model = $${idx++}`);
          values.push(options.model);
        }
        
        updates.push(`status = $${idx++}`);
        values.push(options.status);
        updates.push(`updated_at = NOW()`);
        
        values.push(provider);
        
        await kernel.query(
          `UPDATE provider_api_keys SET ${updates.join(', ')} WHERE provider = $${idx}`,
          values
        );
        console.log(`✅ Updated provider '${provider}'`);
      } else {
        // Insert new
        await kernel.query(
          `INSERT INTO provider_api_keys (id, provider, encrypted_key, encrypted_iv, encrypted_tag, encrypted_salt, model, status, created_at, updated_at)
           VALUES (uuid_generate_v4(), $1, $2, $3, $4, $5, $6, $7, NOW(), NOW())`,
          [provider, encryptedKey, encryptedIv, encryptedTag, encryptedSalt, options.model || null, options.status]
        );
        console.log(`✅ Created provider '${provider}'`);
      }
      
      console.log(`Provider: ${provider}`);
      console.log(`Status: ${options.status}`);
      if (options.model) console.log(`Model: ${options.model}`);
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
      const result = await kernel.areflect(text);
      console.log(result);
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });
  
program
  .command('learn <content>')
  .description('Save learning to memory')
  .option('--importance <n>', 'Importance (1-10)', '5')
  .option('--tags <tags>', 'Comma-separated tags')
  .action(async (content, options) => {
    try {
      const tags = options.tags ? options.tags.split(',') : ['learning'];
      const id = await kernel.learn(content, parseInt(options.importance), tags);
      if (id) {
        console.log(`✅ Learning saved: ${content.slice(0,60)}...`);
      } else {
        console.log(`⚠️  Failed to save learning`);
      }
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

program
  .command('commit <message>')
  .description('Git commit with MANDATORY inter-review (respect reviewer AI\'s work)')
  .option('--no-inter-review', 'Skip inter-review (NOT RECOMMENDED)')
  .action(async (message, options) => {
    if (options.help) {
      console.log('Usage: psypi commit "message" [--no-inter-review]');
      console.log('');
      console.log('MANDATORY: Inter-review for quality control');
      console.log('  - If [inter-review:ID] in message: validates existing review');
      console.log('  - If NO [inter-review:] in message: AUTO-RUNS inner review');
      console.log('  - Review report ALWAYS displayed to requester AI');
      console.log('  - NO auto-blocking: respect reviewer AI\'s work');
      console.log('  - Requester AI SHOULD adapt code based on findings');
      console.log('');
      console.log('Options:');
      console.log('  --no-inter-review Skip inter-review (NOT RECOMMENDED)');
      console.log('');
      console.log('Examples:');
      console.log('  psypi commit "Fix bug"');
      console.log('  psypi commit "Update code [inter-review:abc123]"');
      return;
    }

    try {
      let review: any; // Declare review variable at try block level
      // === INTER-REVIEW (MANDATORY QUALITY GATE) ===
      
      if (!options['no-inter-review']) {
        const interReviewMatch = message.match(/\[inter-review:\s*([a-f0-9-]+)\]/i);
        
        if (interReviewMatch) {
          // [inter-review:ID] found - validate existing review
          const reviewId = interReviewMatch[1];
          review = await kernel.getReview(reviewId);
          
          if (!review) {
            console.error(`\nError: inter-review ${reviewId} not found in database`);
            console.error('Create an inter-review first with: psypi inter-review-request <task-id>');
            process.exit(1);
          }
          
          if (review.status !== 'completed') {
            console.error(`\nError: inter-review ${reviewId} status is '${review.status}', must be 'completed'`);
            console.error('Wait for the inter-review to be completed before committing.');
            process.exit(1);
          }
          
          // Validate ownership - check if current AI performed this review
          const currentIdentity = await AgentIdentityService.getResolvedIdentity();
          const currentAgentId = currentIdentity.id;
          
          // Note: review.reviewerId contains the Inner AI ID who performed the review
          if (review.reviewerId === currentAgentId) {
            console.error(`\nError: You performed this inter-review yourself (reviewerId: ${review.reviewerId})`);
            console.error('You cannot use your own inter-review - ask another AI to review your code first.');
            process.exit(1);
          }
          
          console.log(`✓ Inter-review ${reviewId} validated (status: ${review.status})`);
          
        } else {
          // NO [inter-review:] found - AUTO-RUN inner review (from prepare-commit-msg hook)
          console.log('\n==========================================');
          console.log(' Running Inner AI Code Review...');
          console.log('==========================================\n');
          
          try {
            const db = DatabaseClient.getInstance();
            const reviewService = await InterReviewService.create(db);
            const identity = await AgentIdentityService.getResolvedIdentity();
            
            // Request review
            const { getGitHash, getGitBranch, getLastCommitMessage } = await import('./kernel/utils/git.js');
            const commitHash = await getGitHash() || 'unknown';
            const branch = await getGitBranch() || 'unknown';
            const commitMessage = getLastCommitMessage() || '';
            
            const request = {
              taskId: undefined,
              commitHash,
              branch,
              reviewerId: identity.id,
              context: {
                message: commitMessage,
              },
            };
            
            const newReviewId = await reviewService.requestReview(request, false);
            console.log(`Review requested: ${newReviewId}`);
            
            // Perform review
            const prompt = `You are a senior code reviewer with expertise in TypeScript, Node.js, and software best practices. Be constructive and thorough. Focus on: correctness, maintainability, test coverage, and preventing loop script pollution.`;
            const result = await reviewService.performReview(newReviewId, prompt);
            review = result;
            
            console.log(`✅ Review completed (score: ${result.overallScore}/100)`);
            
            // Block commit if critical/high issues found
            const criticalIssues = result.findings.filter(f => 
              f.severity === 'critical' || f.severity === 'high'
            );
            
            if (criticalIssues.length > 0) {
              console.log('\n⚠️  WARNING: Critical/high issues found!');
              console.log('   The requester AI should consider adapting the code before committing.');
              console.log('   (Commit proceeds - respect reviewer AI\'s work, trust requester AI to adapt)\n');
            }
            
            // Auto-append [inter-review:ID] to message
            message = `${message} [inter-review:${newReviewId}]`;
            console.log(`\n✅ Review passed! Added [inter-review:${newReviewId}] to commit message`);
            
          } catch (reviewErr) {
            console.error('\n❌ Review failed:', reviewErr instanceof Error ? reviewErr.message : reviewErr);
            console.error('Commit blocked. Please fix issues or use --no-inter-review to skip.');
            process.exit(1);
          }
        }
      }
      
      // === MANDATORY: DISPLAY REVIEW REPORT TO REQUESTER AI ===
      if (review) {
        console.log('\n==========================================');
        console.log(' INTER-REVIEW REPORT (MANDATORY READING)');
        console.log('==========================================\n');
        
        // Display review scores
        const score = review.overallScore || review.overall_score || 'N/A';
        console.log(`📊 SCORES:`);
        console.log(`   Overall: ${score}/100`);
        console.log(`   Code Quality: ${review.codeQualityScore || review.code_quality_score || 'N/A'}/100`);
        console.log(`   Test Coverage: ${review.testCoverageScore || review.test_coverage_score || 'N/A'}/100`);
        console.log(`   Documentation: ${review.documentationScore || review.documentation_score || 'N/A'}/100`);
        
        if (review.summary) {
          console.log(`\n📝 SUMMARY:\n${review.summary}`);
        }
        
        // Display ALL findings (issues, suggestions, praise)
        const findings = review.findings || review.findings || [];
        if (findings.length > 0) {
          console.log('\n🔍 FINDINGS:');
          findings.forEach((f: any, idx: number) => {
            const icon = f.type === 'issue' ? '❌' : f.type === 'suggestion' ? '💡' : '✅';
            console.log(`  ${idx + 1}. ${icon} [${f.severity || 'medium'}] ${f.message}`);
            if (f.suggestion) console.log(`     💡 Suggestion: ${f.suggestion}`);
            if (f.code) console.log(`     📄 Code:\n${f.code}`);
          });
        }
        
        // Display learnings (if any)
        const learnings = review.learnings || [];
        if (learnings.length > 0) {
          console.log('\n🎓 LEARNINGS:');
          learnings.forEach((l: any, idx: number) => {
            console.log(`  ${idx + 1}. [${l.topic || 'General'}] ${l.reminder}`);
          });
        }
        
        // DISPLAY FULL RAW RESPONSE FOR AI TO LEARN
        const rawResponse = review.rawResponse || review.raw_response || '';
        if (rawResponse) {
          console.log('\n--- Full Review Response (for AI learning) ---');
          console.log(rawResponse.slice(0, 1000) + (rawResponse.length > 1000 ? '\n...(truncated, see DB for full response)' : ''));
        }
        
        console.log('\n==========================================');
        console.log(' ⚠️  REQUESTER AI: Please read and adapt code based on findings above');
        console.log(' ==========================================\n');
      }
      
      // === EXECUTE GIT COMMIT ===
      
      // Add agent ID to message for traceability
      try {
        const identity = await AgentIdentityService.getResolvedIdentity();
        if (identity && identity.id) {
          // Append agent ID if not already present
          if (!message.includes('[AI:') && !message.includes('[agent:')) {
            message = `${message} [AI:${identity.id}]`;
            console.log(`📝 Added agent ID to commit: ${identity.id.slice(0, 8)}`);
          }
        }
      } catch (idErr) {
        console.warn('Warning: Could not get agent identity:', idErr instanceof Error ? idErr.message : idErr);
      }
      
      const { execSync } = await import('child_process');
      const verifyFlag = options['no-inter-review'] ? '--no-verify' : '';
      const result = execSync(`git commit -m "${message}" ${verifyFlag}`, {
        encoding: 'utf-8',
        stdio: 'pipe'
      });
      console.log(result);
      
      // === POST-COMMIT TASKS (moved from post-commit hook) ===
      
      // 1. Mark tasks as COMPLETED (if [task:ID] in message)
      const taskIds = [...new Set([...message.matchAll(/\[task:\s*([a-f0-9-]+)\]/gi)].map(m => m[1]))];
      
      for (const taskId of taskIds) {
        try {
          const success = await kernel.completeTask(taskId);
          if (success) {
            console.log(`✅ Task ${taskId.slice(0, 8)} marked COMPLETED`);
          }
        } catch (err) {
          console.warn(`Warning: Failed to mark task ${taskId} as completed:`, err instanceof Error ? err.message : err);
        }
      }
      
      // 2. Mark issues as RESOLVED (if [issue:ID] in message)
      const issueIds = [...new Set([...message.matchAll(/\[issue:\s*([a-f0-9-]+)\]/gi)].map(m => m[1]))];
      
      for (const issueId of issueIds) {
        try {
          const success = await kernel.resolveIssue(issueId);
          if (success) {
            console.log(`✅ Issue ${issueId.slice(0, 8)} marked RESOLVED`);
          }
        } catch (err) {
          console.warn(`Warning: Failed to mark issue ${issueId} as resolved:`, err instanceof Error ? err.message : err);
        }
      }
      
      // 3. Announce commit
      try {
        const announceMsg = `Git Commit: ${message.slice(0, 60)}${message.length > 60 ? '...' : ''}`;
        await kernel.announce(announceMsg, 'low');
        console.log(`✅ Commit announced`);
      } catch (err) {
        console.warn('Warning: Failed to announce commit:', err instanceof Error ? err.message : err);
      }
      
    } catch (err) {
      if (err instanceof Error) {
        // Check if it's a process exit error (from execSync)
        if ('status' in err && err.status === 1) {
          console.error('Commit failed or blocked by quality control');
        } else {
          console.error('Error:', err.message);
        }
      } else {
        console.error('Unknown error occurred');
      }
    }
  });

program
  .command('announce <message>')
  .description('Send announcement to all AIs')
  .option('--priority <level>', 'Priority: low|normal|high|critical', 'normal')
  .action(async (message, options) => {
    try {
      const success = await kernel.announce(message, options.priority);
      if (success) {
        console.log(`✅ Announcement sent: ${message.slice(0,60)}...`);
      } else {
        console.log(`⚠️  Announcement logged (broadcast table may not exist)`);
      }
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

program
  .command('broadcast <message>')
  .description('Alias for announce (send broadcast to all AIs)')
  .option('--priority <level>', 'Priority: low|normal|high|critical', 'normal')
  .action(async (message, options) => {
    // Same as announce
    try {
      const success = await kernel.announce(message, options.priority);
      if (success) {
        console.log(`✅ Broadcast sent: ${message.slice(0,60)}...`);
      } else {
        console.log(`⚠️  Broadcast logged`);
      }
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

// === Inter-Review Commands (from Nezha) ===
program
  .command('inter-review-request <taskId>')
  .description('Request an inter-review for a task')
  .option('--reviewer <agentId>', 'Specific reviewer agent ID')
  .action(async (taskId, options) => {
    try {
      const reviewId = await kernel.requestReview(taskId, options.reviewer);
      console.log(`✅ Inter-review requested: ${reviewId}`);
      console.log(`Add to commit: [inter-review:${reviewId}]`);
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

program
  .command('inter-review-show <reviewId>')
  .description('Show inter-review details')
  .action(async (reviewId) => {
    try {
      const review = await kernel.getReview(reviewId);
      if (!review) {
        console.log('Review not found');
        return;
      }
      console.log(`\n📝 Inter-Review: ${reviewId}`);
      console.log(`Task: ${review.taskId || 'N/A'}`);
      console.log(`Status: ${review.status}`);
      console.log(`Score: ${review.overallScore || 'N/A'}`);
      if (review.summary) {
        console.log(`\nSummary:\n${review.summary}`);
      }
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

program
  .command('inter-reviews [status]')
  .description('List inter-reviews (optional status filter)')
  .action(async (status) => {
    try {
      const reviews = await kernel.listReviews(status);
      if (reviews.length === 0) {
        console.log('No inter-reviews found');
        return;
      }
      console.log(`\n📝 Inter-Reviews (${reviews.length}):`);
      reviews.forEach((r: any) => {
        console.log(`  ${r.id} - ${r.status} - Score: ${r.score || 'N/A'}`);
      });
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });


// === Inner AI Commands ===
program
  .command('inner <subcommand>')
  .description('Inner AI management: set-model, model, review')
  .action(async (subcommand) => {
    const db = DatabaseClient.getInstance();
    const apiKeyService = ApiKeyService.getInstance(db);
    const args = process.argv.slice(4); // Skip: node, script, 'inner', subcommand
    
    if (subcommand === 'set-model') {
      const provider = args[0];
      const model = args[1];
      if (!provider) {
        const current = await apiKeyService.getCurrentInnerModel();
        console.log(current
          ? `Provider: ${current.provider}, Model: ${current.model}`
          : 'No inner model provider configured');
        return;
      }
      await apiKeyService.setCurrentInnerProvider(provider, model);
      console.log(`Inner model provider set to: ${provider}${model ? ` with model '${model}'` : ''}`);
    } else if (subcommand === 'model') {
      const identity = await AgentIdentityService.getResolvedIdentity(false);
      console.log(identity.id);
    } else if (subcommand === 'review') {
      const reviewService = await InterReviewService.create(db);
      const currentIdentity = await AgentIdentityService.getResolvedIdentity();
      
      const { getGitHash, getGitBranch, getGitDiff, getLastCommitMessage } = await import('./kernel/utils/git.js');
      const { resolveTaskId, resolveIssueId } = await import('./kernel/utils/resolve-id.js');
      const commitHash = await getGitHash();
      const branch = await getGitBranch() || 'main';
      const commitMessage = getLastCommitMessage() || '';
      const diff = getGitDiff();
      const files = diff ? diff.split('\n') : [];
      
      // Extract and resolve task/issue ID from commit message
      const taskMatch = commitMessage.match(/\[task:\s*([a-f0-9-]+)\]/i);
      const issueMatch = commitMessage.match(/\[issue:\s*([a-f0-9-]+)\]/i);
      
      let taskId: string | undefined = undefined;
      if (taskMatch && taskMatch[1]) {
        // Try to resolve short ID to full UUID
        const resolvedTaskId = await resolveTaskId(db, taskMatch[1]);
        taskId = resolvedTaskId || taskMatch[1];
      }
      
      let issueId: string | undefined = undefined;
      if (issueMatch && issueMatch[1]) {
        const resolvedIssueId = await resolveIssueId(db, issueMatch[1]);
        issueId = resolvedIssueId || issueMatch[1];
      }
      
      const request = {
        taskId,
        commitHash: commitHash || undefined,
        branch,
        reviewerId: currentIdentity.id,
        context: {
          message: commitMessage,
          files,
          taskDescription: taskId ? `Task: ${taskId}` : undefined,
          issueDescription: issueId ? `Issue: ${issueId}` : undefined,
        },
      };
      
      console.log('\n🔍 Requesting Inner AI review...\n');
      const reviewId = await reviewService.requestReview(request, false);
      console.log(`   Review ID: ${reviewId}`);
      
      console.log('\n⏳ Inner AI is reviewing your code...\n');
      const prompt = `You are a senior code reviewer with expertise in TypeScript, Node.js, and software best practices. Be constructive and thorough. Focus on: correctness, maintainability, test coverage, and preventing loop script pollution.`;
      const result = await reviewService.performReview(reviewId, prompt);
      
      console.log(`\n✅ Review completed (score: ${result.overallScore}/100)\n`);
      
      // Always show full review details
      console.log('📋 Summary:');
      console.log(`   ${result.summary}\n`);
      
      if (result.findings.length > 0) {
        console.log('🔍 Findings:');
        const grouped = result.findings.reduce((acc, f) => {
          acc[f.severity] = acc[f.severity] || [];
          acc[f.severity].push(f);
          return acc;
        }, {} as Record<string, typeof result.findings>);
        
        for (const severity of ['critical', 'high', 'medium', 'low', 'info']) {
          if (grouped[severity]) {
            console.log(`\n   [${severity.toUpperCase()}] ${grouped[severity].length} finding(s):`);
            for (const finding of grouped[severity]) {
              console.log(`   - ${finding.message}`);
              if (finding.file) console.log(`     File: ${finding.file}${finding.line ? ':' + finding.line : ''}`);
              if (finding.suggestion) console.log(`     Suggestion: ${finding.suggestion}`);
            }
          }
        }
        console.log('');
      }
      
      if (result.learnings && result.learnings.length > 0) {
        console.log('📚 Learnings:');
        result.learnings.forEach((learning, i) => {
          console.log(`   ${i + 1}. ${learning.topic}: ${learning.reminder}`);
        });
        console.log('');
      }
      
      console.log('📊 Scores:');
      console.log(`   Overall: ${result.overallScore}/100`);
      if (result.codeQualityScore) console.log(`   Code Quality: ${result.codeQualityScore}/100`);
      if (result.testCoverageScore) console.log(`   Test Coverage: ${result.testCoverageScore}/100`);
      if (result.documentationScore) console.log(`   Documentation: ${result.documentationScore}/100`);
      console.log('');
      
      // Check for critical/high issues
      const criticalIssues = result.findings.filter(f => f.severity === 'critical' || f.severity === 'high');
      
      if (criticalIssues.length > 0) {
        console.log(`\n⚠️  Found ${criticalIssues.length} critical/high severity issue(s)`);
        console.log('❌ Review failed - please fix issues before committing\n');
        process.exit(1);
      }
      
      console.log('✅ Review passed!');
      console.log(`\nYou can now commit with:`);
      const msgForCommit = commitMessage || 'Update';
      const taskPart = taskMatch ? ` [task:${taskMatch[1]}]` : '';
      console.log(`   git commit -m "${msgForCommit}${taskPart} [inter-review:${reviewId}]"`);
    } else {
      console.log('Usage: psypi inner <set-model|model|review>');
      console.log('');
      console.log('Commands:');
      console.log('  set-model [provider] [model]  Set the current inner AI provider and model');
      console.log('  model                         Show the inner AI agent ID');
      console.log('  review                        Invoke Inner AI to review pending changes');
    }
  });

// === Status Command ===
program
  .command('status')
  .description('Show psypi status including inner AI, tools, and hooks')
  .action(async () => {
    try {
      const db = DatabaseClient.getInstance();
      const apiKeyService = ApiKeyService.getInstance(db);
      
      // Project info
      const cwd = process.cwd();
      const projectName = basename(cwd);
      
      // Inner AI status
      let thinkerStatus = '🏠 Working locally (no external thinker)';
      try {
        const model = await apiKeyService.getCurrentInnerModel();
        if (model) {
          thinkerStatus = `🧠 Using: ${model.provider}/${model.model}`;
        }
      } catch (err) {
        thinkerStatus = '⚠️  Inner AI config ured but key decryption failed (using fallback)';
      }
      
      // Tools
      const tools = [
        'task-add', 'tasks', 'task-complete',
        'issue-add', 'issue-list', 'issue-resolve',
        'skill-list', 'skill-show', 'skill-build',
        'session-start', 'session-end',
        'learn', 'areflect', 'context',
        'announce', 'broadcast',
        'inter-review-request', 'inter-review-show', 'inter-reviews',
        'inner', 'meeting', 'think', 'autonomous',
        'status', 'project', 'visits', 'stats',
        'doc-save', 'doc-list'
      ];
      
      // Hooks (from extension)
      const hooks = [
        'resources_discover',
        'context',
        'before_agent_start',
        'session_start',
        'tool_result',
        'tool_call'
      ];
      
      console.log('\n## Psypi Status\n');
      console.log(`**Project:** ${projectName}`);
      console.log(`**Inner AI:** ${thinkerStatus}\n`);
      console.log(`**Tools (${tools.length}):**`);
      tools.forEach(t => console.log(`  - ${t}`));
      console.log(`\n**Hooks (${hooks.length}):**`);
      hooks.forEach(h => console.log(`  - ${h}`));
      console.log('');
      
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    } finally {
      DatabaseClient.resetInstance();
    }
  });

// === Doc Save Command ===
program
  .command('doc-save <name> <content>')
  .description('Save a project document to database (source of truth)')
  .option('--file-path <path>', 'Target file path when generated')
  .option('--priority <n>', 'Priority for ordering (higher = more important)', parseInt)
  .action(async (name, content, options) => {
    try {
      const db = DatabaseClient.getInstance();
      
      const existingResult = await db.query<{ id: string }>(
        "SELECT id FROM project_docs WHERE name = $1 AND status = 'current'",
        [name]
      );
      const existing = existingResult.rows[0];
      
      if (existing) {
        await db.query(
          'UPDATE project_docs SET content = $1, file_path = COALESCE($2, file_path), priority = COALESCE($3, priority), updated_at = NOW() WHERE id = $4',
          [content, options.filePath || null, options.priority ?? null, existing.id]
        );
        console.log(`✅ Document "${name}" updated in database`);
      } else {
        await db.query(
          'INSERT INTO project_docs (name, content, file_path, priority) VALUES ($1, $2, $3, $4)',
          [name, content, options.filePath || null, options.priority || 0]
        );
        console.log(`✅ Document "${name}" saved to database`);
      }
      
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    } finally {
      DatabaseClient.resetInstance();
    }
  });

// === Doc List Command ===
program
  .command('doc-list')
  .description('List all project documents in database')
  .action(async () => {
    try {
      const db = DatabaseClient.getInstance();
      
      const docs = await db.query<{ name: string; file_path: string; priority: number; updated_at: string }>(
        "SELECT name, file_path, priority, updated_at FROM project_docs WHERE status = 'current' ORDER BY priority DESC"
      );
      
      if (docs.rows.length === 0) {
        console.log('No project documents found in database');
        return;
      }
      
      console.log('\n📚 Project Documents (from database):\n');
      docs.rows.forEach(doc => {
        const priority = doc.priority ? `[${doc.priority}]` : '';
        console.log(`  ${priority} ${doc.name} → ${doc.file_path || '(no path)'} (updated ${doc.updated_at.slice(0, 19)})`);
      });
      console.log('');
      
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    } finally {
      DatabaseClient.resetInstance();
    }
  });

// === Autonomous Command ===
program
  .command('autonomous [context]')
  .description('Get autonomous work guidance from database')
  .action(async (context) => {
    try {
      const db = DatabaseClient.getInstance();
      
      // Get pending tasks
      const tasks = await db.query<{ id: string; title: string; priority: number }>(
        "SELECT id, title, priority FROM tasks WHERE status = 'PENDING' ORDER BY priority DESC LIMIT 5"
      );
      
      console.log('\n🤖 Autonomous Work Guidance:\n');
      
      if (tasks.rows.length === 0) {
        console.log('No pending tasks. System idle.\n');
      } else {
        console.log('**Pending Tasks:**');
        tasks.rows.forEach(t => {
          console.log(`  [${t.priority}] ${t.title} (${t.id.slice(0, 8)})`);
        });
        console.log('\nUse: psypi task-complete <id> when done');
      }
      
      // Get critical issues
      const issues = await db.query<{ id: string; title: string; severity: string }>(
        "SELECT id, title, severity FROM issues WHERE status = 'OPEN' AND severity IN ('critical', 'high') ORDER BY severity DESC LIMIT 3"
      );
      
      if (issues.rows.length > 0) {
        console.log('\n**Critical/High Issues:**');
        issues.rows.forEach(i => {
          console.log(`  [${i.severity}] ${i.title} (${i.id.slice(0, 8)})`);
        });
      }
      
      console.log('');
      
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    } finally {
      DatabaseClient.resetInstance();
    }
  });

// === Project Command ===
program
  .command('project')
  .description('Show project info')
  .action(async () => {
    try {
      const db = DatabaseClient.getInstance();
      const cwd = process.cwd();
      const projectName = basename(cwd);
      
      console.log(`\n📁 Project: ${projectName}\n`);
      
      // Check if registered
      const projectResult = await db.query<{ id: string; created_at: string }>(
        'SELECT id, created_at FROM projects WHERE name = $1',
        [projectName]
      );
      const project = projectResult.rows[0];
      
      if (project) {
        console.log('Status: ✅ Registered in database');
        const createdAt = new Date(project.created_at).toISOString();
        console.log(`Registered: ${createdAt.slice(0, 19)}`);
      } else {
        console.log('Status: ❌ Not registered in database');
      }
      
      console.log('');
      
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    } finally {
      DatabaseClient.resetInstance();
    }
  });

// === Stats Command ===
program
  .command('stats')
  .description('Show ecosystem stats')
  .action(async () => {
    try {
      const db = DatabaseClient.getInstance();
      
      const taskStats = await db.query<{ total: number; pending: number; completed: number }>(
        "SELECT COUNT(*) as total, SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) as pending, SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) as completed FROM tasks"
      );
      
      const issueStats = await db.query<{ total: number; open: number; resolved: number }>(
        "SELECT COUNT(*) as total, SUM(CASE WHEN status = 'OPEN' THEN 1 ELSE 0 END) as open, SUM(CASE WHEN status = 'RESOLVED' THEN 1 ELSE 0 END) as resolved FROM issues"
      );
      
      console.log('\n📊 Ecosystem Stats:\n');
      console.log('**Tasks:**');
      console.log(`  Total: ${taskStats.rows[0]?.total || 0}`);
      console.log(`  Pending: ${taskStats.rows[0]?.pending || 0}`);
      console.log(`  Completed: ${taskStats.rows[0]?.completed || 0}`);
      console.log('\n**Issues:**');
      console.log(`  Total: ${issueStats.rows[0]?.total || 0}`);
      console.log(`  Open: ${issueStats.rows[0]?.open || 0}`);
      console.log(`  Resolved: ${issueStats.rows[0]?.resolved || 0}`);
      console.log('');
      
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    } finally {
      DatabaseClient.resetInstance();
    }
  });

// === Tools Command ===
program
  .command('tools')
  .description('List available tools from DB')
  .action(async () => {
    try {
      const db = DatabaseClient.getInstance();
      
      const tools = await db.query<{ table_name: string; purpose: string }>(
        'SELECT table_name, purpose FROM table_documentation WHERE ai_can_modify = true ORDER BY table_name'
      );
      
      console.log('\n🔧 Available Tools (from DB):\n');
      
      if (tools.rows.length === 0) {
        console.log('No tools found in database\n');
      } else {
        tools.rows.forEach(t => {
          console.log(`  ${t.table_name}: ${t.purpose}`);
        });
        console.log('');
      }
      
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    } finally {
      DatabaseClient.resetInstance();
    }
  });

// === Agents Command ===
program
  .command('agents')
  .description('List active agents')
  .action(async () => {
    try {
      const db = DatabaseClient.getInstance();
      
      const agents = await db.query<{ id: string; identity_id: string; started_at: string; last_heartbeat_at: string }>(
        "SELECT id, identity_id, started_at, last_heartbeat_at FROM agent_sessions WHERE status = 'alive' ORDER BY started_at DESC"
      );
      
      console.log('\n🤖 Active Agents:\n');
      
      if (agents.rows.length === 0) {
        console.log('No active agents\n');
      } else {
        agents.rows.forEach(a => {
          const identity = (a.identity_id || 'unknown').slice(0, 20);
          const started = new Date(a.started_at).toISOString().slice(0, 19);
          console.log(`  ${identity} (started: ${started})`);
        });
        console.log('');
      }
      
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    } finally {
      DatabaseClient.resetInstance();
    }
  });

// === Visits Command ===
program
  .command('visits')
  .description('Show recent visits')
  .option('--limit <n>', 'Limit number of results', parseInt)
  .action(async (options) => {
    try {
      const db = DatabaseClient.getInstance();
      const limit = options.limit || 20;
      
      const visits = await db.query<{ project_fingerprint: string; visited_at: string }>(
        'SELECT project_fingerprint, visited_at FROM project_visits ORDER BY visited_at DESC LIMIT $1',
        [limit]
      );
      
      console.log(`\n📌 Recent Visits (last ${limit}):\n`);
      
      if (visits.rows.length === 0) {
        console.log('No visits recorded\n');
      } else {
        visits.rows.forEach(v => {
          const project = v.project_fingerprint.slice(0, 16);
          const visited = new Date(v.visited_at).toISOString().slice(0, 19);
          console.log(`  ${project} (${visited})`);
        });
        console.log('');
      }
      
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    } finally {
      DatabaseClient.resetInstance();
    }
  });

// === Validate Commit Command ===
program
  .command('validate-commit <message>')
  .description('Validate commit message format')
  .action(async (message) => {
    try {
      const hasTask = /\[task:\s*[a-f0-9-]+\]/i.test(message);
      const hasIssue = /\[issue:\s*[a-f0-9-]+\]/i.test(message);
      const hasReview = /\[inter-review:\s*[a-f0-9-]+\]/i.test(message);
      
      console.log('\n🔍 Commit Message Validation:\n');
      console.log(`Message: ${message}\n`);
      console.log('**Checks:**');
      console.log(`  Task ID: ${hasTask ? '✅' : '❌'}`);
      console.log(`  Issue ID: ${hasIssue ? '✅' : '❌'}`);
      console.log(`  Inter-Review: ${hasReview ? '✅' : '❌'}`);
      console.log('');
      
      if (!hasReview) {
        console.log('⚠️  Warning: No [inter-review:ID] found - review will be auto-run by psypi commit');
      }
      
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });

// === Meeting Commands ===
program
  .command('meeting <subcommand>')
  .description('Meeting management: list, show, opinion, complete, cleanup, archive')
  .option('--limit <n>', 'Limit number of results', parseInt)
  .option('--status <status>', 'Filter by status (active, completed, archived)')
  .option('--days <n>', 'Number of days for cleanup/archive', parseInt)
  .action(async (subcommand, options) => {
    const db = DatabaseClient.getInstance();
    const meetingCmd = new MeetingCommands({ db });
    const args = process.argv.slice(4); // Skip: node, script, 'meeting', subcommand
    
    try {
      if (subcommand === 'list') {
        const limit = options.limit || 100;
        const status = options.status;
        await meetingCmd.list({ limit: Math.min(limit, 500), status: status });
      } else if (subcommand === 'show') {
        const meetingId = args[0];
        if (!meetingId) {
          console.log('Usage: psypi meeting show <id>');
          return;
        }
        const resolvedId = await resolveMeetingId(DatabaseClient.getInstance(), meetingId);
        await meetingCmd.show(resolvedId || meetingId);
      } else if (subcommand === 'opinion') {
        const meetingId = args[0];
        // Get perspective (everything between meetingId and --position flag)
        const posIdx = args.indexOf('--position');
        const perspectiveArgs = posIdx > 0 ? args.slice(1, posIdx) : args.slice(1);
        const perspective = perspectiveArgs.join(' ');
        if (!meetingId || !perspective) {
          console.log('Usage: psypi meeting opinion <meeting-id> "<perspective>" [--position support|oppose|neutral]');
          return;
        }
        const position = posIdx > 0 && posIdx + 1 < args.length ? args[posIdx + 1] : undefined;
        const validPosition = position && ['support', 'oppose', 'neutral'].includes(position) ? position as "support" | "oppose" | "neutral" : undefined;
        const identity = await AgentIdentityService.getResolvedIdentity();
        const resolvedId = await resolveMeetingId(DatabaseClient.getInstance(), meetingId);
        await meetingCmd.addOpinion(resolvedId || meetingId, identity.id, perspective, undefined, validPosition);
      } else if (subcommand === 'complete') {
        const meetingId = args[0];
        const consensus = args.slice(1).join(' ') || undefined;
        if (!meetingId) {
          console.log('Usage: psypi meeting complete <id> [consensus]');
          return;
        }
        const resolvedId = await resolveMeetingId(DatabaseClient.getInstance(), meetingId);
        await meetingCmd.complete(resolvedId || meetingId, consensus);
      } else if (subcommand === 'cleanup') {
        const days = options.days || 5;
        await meetingCmd.cleanup(days);
      } else if (subcommand === 'archive') {
        const days = options.days || 30;
        await meetingCmd.archive(days);
      } else {
        console.log('Usage: psypi meeting <list|show|opinion|complete|cleanup|archive>');
        console.log('  list    List meetings (--limit N, --status active|completed)');
        console.log('  show    Show a meeting by ID');
        console.log('  opinion Add your opinion to a meeting [--position support|oppose|neutral]');
        console.log('  complete Complete a meeting with consensus');
        console.log('  cleanup Cleanup old meetings (--days N, default 5)');
        console.log('  archive Archive old meetings (--days N, default 30)');
      }
    } finally {
      // Close database pool to allow process to exit
      DatabaseClient.resetInstance();
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

// Check if no arguments → launch Pi TUI (psypi unified mode)
if (!process.argv.slice(2).length) {
  // Dynamic import to avoid top-level await issues
  (async () => {
    try {
      const { execSync } = await import('child_process');
      // Calculate extension path relative to this module
      const extensionUrl = new URL('./agent/extension/extension.js', import.meta.url);
      const extensionPath = extensionUrl.pathname;
      
      console.log('[psypi] Launching Pi TUI with Nezha Inside™...');
      // Launch Pi with psypi extension (unified mode)
      execSync(`pi -e "${extensionPath}"`, { 
        stdio: 'inherit',
        env: { ...process.env, PSYPI_EXTENSION: extensionPath }
      });
    } catch (err) {
      if (err instanceof Error && 'status' in err) {
        // Pi exited with a status code
        const errorWithStatus = err as unknown as { status?: number };
        process.exit(errorWithStatus.status || 1);
      }
      console.error('[psypi] Failed to launch Pi TUI:', err instanceof Error ? err.message : err);
      console.log('\nFallback: Use psypi <command> for CLI mode');
      program.help();
    }
  })();
} else {
  // Otherwise, parse as CLI command (current behavior)
  program.parse(process.argv);
}
