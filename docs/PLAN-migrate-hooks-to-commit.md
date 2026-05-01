# Plan: Migrate Git Hooks to `psypi commit` Command (FINAL)

**Date**: 2026-05-02  
**Status**: Implementation Ready - Respect Reviewer AI's Work  
**Related Issue**: `76359b45-1a8a-46af-ad66-db26e0127489`

---

## Core Philosophy: Respect Reviewer AI's Work

**Key Principle**: 
- The **reviewer AI's work must be respected**
- QC should **NOT auto-block** based on scores
- **Requester AI MUST read** the review report
- **Requester AI SHOULD adapt** code based on findings
- Commit proceeds only after requester AI acknowledges review

**Flow**:
1. Review runs (auto or from `[inter-review:ID]`)
2. **Review report ALWAYS displayed** to requester AI
3. **Requester AI reads** findings carefully
4. **Requester AI adapts code** if needed
5. **Requester AI commits** (with or without changes)

---

## Executive Summary

**SIMPLIFIED APPROACH**:
- ❌ **NO** task/issue ID required in commit message
- ✅ **MANDATORY**: Inter-review (either provided or auto-run)
- ✅ **MANDATORY**: Requester AI reads review report (displayed always)
- ❌ **NO** auto-blocking on critical/high issues (respect reviewer's work)
- ✅ **Requester AI's responsibility** to adapt code based on review
- ✅ Post-commit tasks: Mark tasks/issues complete, announce

**Goal**: Consolidate git hooks into `psypi commit` with proper respect for reviewer AI's work.

---

## Investigation Results

### Current State

#### Git Hooks (in `.git/hooks/`)

| Hook | Status | Functionality |
|------|--------|---------------|
| `prepare-commit-msg` | ❌ NOT INSTALLED (.bak exists) | **Pre-commit**: Auto-runs `inner review` if no `[inter-review:]` in message, blocks commit on failure |
| `post-commit` | ✅ INSTALLED | **Post-commit**: Marks tasks COMPLETED, issues RESOLVED, sends announcement |

**Problem with current `prepare-commit-msg`**: 
- Auto-blocks commit on critical issues
- **Does NOT respect reviewer AI's work** - reviewer spent time, but coder ignores it
- Forces re-commit without ensuring coder actually reads/adapts

#### `psypi commit` Command (in `src/cli.ts:372-420`)

**Currently does**:
- ✅ Validates commit message has task/issue ID (`[task:xxx]` or `[issue:xxx]`) - **TO BE REMOVED**
- ✅ Executes `git commit`
- ❌ Does NOT do post-commit tasks (mark complete, announce)

---

## The FINAL Plan (Respect Reviewer AI)

### Phase 1: Rewrite `psypi commit` Command

**File**: `src/cli.ts` (lines 372-420)

**New logic (respecting reviewer AI's work)**:
```typescript
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
      console.log('  - Requester AI SHOULD adapt code based on findings');
      console.log('  - NO auto-blocking: respect reviewer AI\'s work');
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
      // === INTER-REVIEW (MANDATORY QUALITY GATE) ===
      
      if (!options['no-inter-review']) {
        const interReviewMatch = message.match(/\[inter-review:\s*([a-f0-9-]+)\]/i);
        
        let review;
        let reviewId;
        
        if (interReviewMatch) {
          // [inter-review:ID] found - validate existing review
          reviewId = interReviewMatch[1];
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
          
          // Note: review.reviewed_by field contains the Inner AI ID who performed the review
          if (review.reviewed_by === currentAgentId) {
            console.error(`\nError: You performed this inter-review yourself (reviewed_by: ${review.reviewed_by})`);
            console.error('You cannot use your own inter-review - ask another AI to review your code first.');
            process.exit(1);
          }
          
          console.log(`✓ Inter-review ${reviewId} validated (status: ${review.status})`);
          
        } else {
          // NO [inter-review:] found - AUTO-RUN inner review
          console.log('\n==========================================');
          console.log(' Running Inner AI Code Review...');
          console.log('==========================================\n');
          
          try {
            const reviewService = await InterReviewService.create(kernel.db);
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
            
            reviewId = await reviewService.requestReview(request, false);
            console.log(`Review requested: ${reviewId}`);
            
            // Perform review
            const prompt = `You are a senior code reviewer with expertise in TypeScript, Node.js, and software best practices. Be constructive and thorough. Focus on: correctness, maintainability, test coverage, and preventing loop script pollution.`;
            const result = await reviewService.performReview(reviewId, prompt);
            
            review = result;
            
            // Auto-append [inter-review:ID] to message
            message = `${message} [inter-review:${reviewId}]`;
            console.log(`\n✅ Review completed! Added [inter-review:${reviewId}] to commit message`);
            
          } catch (reviewErr) {
            console.error('\n❌ Review failed:', reviewErr instanceof Error ? reviewErr.message : reviewErr);
            console.error('Commit blocked. Please fix issues or use --no-inter-review to skip.');
            process.exit(1);
          }
        }
        
        // === MANDATORY: DISPLAY REVIEW REPORT TO REQUESTER AI ===
        console.log('\n==========================================');
        console.log(' INTER-REVIEW REPORT (MANDATORY READING)');
        console.log('==========================================\n');
        
        // Display review summary and scores
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
        
        // NOTE: We do NOT auto-block on critical/high issues
        // The reviewer AI's work is respected - it's the requester AI's responsibility
        // to read and adapt the code. The commit proceeds after review.
        
        // Optional: Show warning but don't block
        const criticalFindings = findings.filter((f: any) => 
          f.type === 'issue' && (f.severity === 'critical' || f.severity === 'high')
        );
        
        if (criticalFindings.length > 0) {
          console.log('⚠️  WARNING: Critical/high severity issues found!');
          console.log('   The requester AI should consider adapting the code before committing.');
          console.log('   (Commit proceeds - respect reviewer AI\'s work, trust requester AI to adapt)\n');
        }
        
      }
      
      // === EXECUTE GIT COMMIT ===
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
```

---

### Phase 2: Deprecate Git Hooks

#### 2.1 Modify `psypi setup-hooks` Command

**File**: `src/cli.ts` (search for `setup-hooks`)

```typescript
program
  .command('setup-hooks')
  .description('[DEPRECATED] Git hooks are replaced by `psypi commit`')
  .action(async () => {
    console.log('⚠️  DEPRECATION WARNING');
    console.log('');
    console.log('Git hooks are deprecated. Use `psypi commit` instead.');
    console.log('');
    console.log('Example:');
    console.log('  psypi commit "Fix bug"');
    console.log('');
    console.log('The `psypi commit` command now handles:');
    console.log('  ✅ MANDATORY inter-review (auto-runs if not provided)');
    console.log('  ✅ ALWAYS shows review report to requester AI');
    console.log('  ✅ NO auto-blocking: respects reviewer AI\'s work');
    console.log('  ✅ Post-commit tasks (mark complete, announce)');
    console.log('');
    console.log('No git hooks needed!');
  });
```

#### 2.2 Deprecate Kernel `setupHooks()` Method

**File**: `src/kernel/index.ts` (around line 240)

```typescript
async setupHooks(projectRoot: string = process.cwd()): Promise<{success: boolean; message: string}> {
  console.warn('[DEPRECATED] setupHooks() is deprecated. Use `psypi commit` command instead.');
  return { 
    success: false, 
    message: 'Git hooks are deprecated. Use `psypi commit` command.' 
  };
}
```

---

## Key Feature: Respect Reviewer AI's Work

**Why this approach is correct**:

1. **Reviewer AI's time is valuable**: They spent time reviewing - coder should at least READ it
2. **No auto-blocking**: Trust the requester AI to make the right decision after reading
3. **Mandatory reading**: Review report ALWAYS displayed (full findings + raw response)
4. **AI learning**: Full raw response shown for future improvement
5. **Responsibility**: It's the requester AI's job to adapt code based on review

**What gets displayed** (ALWAYS, no matter the score):
- Review scores (overall, code quality, test coverage, documentation)
- Summary
- **ALL findings** (issues, suggestions, praise) with severity
- **Learnings** (if any)
- **Full raw response** (first 1000 chars) for AI learning

**Flow after review**:
1. Requester AI reads the full report
2. Requester AI decides: adapt code or commit as-is
3. Requester AI modifies code if needed
4. Requester AI runs `psypi commit` again (new review if code changed)
5. OR Requester AI commits as-is (respecting reviewer's findings)

---

## Benefits of This Approach

| Benefit | Description |
|--------|-------------|
| **Respects reviewer** | Reviewer AI's work is always read and considered |
| **No auto-blocking** | Commit proceeds after review (trust the AI) |
| **AI learning** | Full review report + raw response shown |
| **Simplicity** | No mandatory task/issue ID - just run `psypi commit "message"` |
| **Quality Control** | Inter-review is MANDATORY - ensures code quality |
| **Single Entry Point** | All commit logic in one command |
| **No Hook Conflicts** | Git hooks can cause issues in Docker, CI/CD |

---

## Files to Modify

### Primary Changes (Phase 1)
1. **`src/cli.ts`**
   - Line 372-420: **REWRITE** `commit` command with new logic
   - Remove task/issue ID requirement
   - Make inter-review MANDATORY (auto-run if not provided)
   - **ALWAYS display review report** (scores, findings, learnings, raw response)
   - **NO auto-blocking** on critical issues (respect reviewer AI)
   - Add post-commit tasks (from post-commit hook)

2. **`src/cli.ts`**
   - Search for `setup-hooks`: Deprecate command

3. **`src/kernel/index.ts`**
   - Line ~240: Deprecate `setupHooks()` method

### Documentation Updates (Phase 3)
4. **`AGENTS.md`**
   - Update "Available Commands" section
   - Document new workflow (respect reviewer AI)

5. **`README.md`**
   - Update usage examples
   - Add migration notice

---

## Implementation Priority

### High Priority (Do First)
- [ ] Phase 1: Rewrite `psypi commit` with new logic
- [ ] Test: `psypi commit "Test"` auto-runs review
- [ ] Test: Review report ALWAYS displayed (no matter score)
- [ ] Test: Commit proceeds even with critical issues (no auto-block)

### Medium Priority (Do Next)
- [ ] Phase 2: Deprecate `setup-hooks` command
- [ ] Phase 2: Deprecate `setupHooks()` in kernel

### Low Priority (Do Later)
- [ ] Phase 3: Update documentation
- [ ] Clean up old hook-related code

---

## Testing Plan

### Test Case 1: Basic Commit (Auto-Review + Report Display)
```bash
echo "Test change" > test.txt
git add test.txt
psypi commit "Fix bug"
# Verify: Inner AI review runs automatically
# Verify: [inter-review:NEW_ID] auto-appended to message
# Verify: Review report ALWAYS displayed (scores, findings, learnings)
# Verify: Full raw response shown (for AI learning)
# Verify: Commit SUCCEEDS (even if critical issues found)
# Verify: NO auto-blocking
```

### Test Case 2: Commit with Existing Review (Report Display)
```bash
# First, request a review
psypi inter-review-request TASK_ID
# Note the review ID
git add .
psypi commit "Update code [inter-review:REVIEW_ID]"
# Verify: Review validated
# Verify: Review report ALWAYS displayed to requester AI
# Verify: Commit proceeds (no auto-block)
```

### Test Case 3: Critical Issues Found (NO Auto-Block)
```bash
# Make changes that trigger critical issues
git add .
psypi commit "Bad code"
# Verify: Review runs, finds critical issues
# Verify: Review report displayed (including critical findings)
# Verify: WARNING shown: "Consider adapting code"
# Verify: Commit PROCEEDS (no auto-block, respect reviewer AI)
```

### Test Case 4: Skip Inter-Review (NOT RECOMMENDED)
```bash
psypi commit "Quick fix" --no-inter-review
# Verify: Commit succeeds without review
# Warning: NOT RECOMMENDED for real QC
```

---

## Migration Timeline

| Date | Action |
|------|--------|
| 2026-05-02 | Implement Phase 1: New `psypi commit` (respect reviewer AI) |
| 2026-05-03 | Test and announce deprecation |
| 2026-05-10 | Phase 2 complete: hooks officially deprecated |
| 2026-06-01 | Remove hook installation from codebase |

---

## Notes

- **Inter-review column naming**: The database has confusing column names (`reviewer_id` = requester, `reviewed_by` = reviewer). This will be fixed during the database migration (see issue `5508d0b4`).

- **Backwards compatibility**: Keep `setupHooks()` method but make it print deprecation warning.

- **Current `post-commit` hook**: Can be left in place for users who already have it installed. New installs won't get it (since `setup-hooks` is deprecated).

- **Review Report Display**: Even if score is 100/100, the report is shown to help the AI learn and potentially improve the code further before committing.

- **No Auto-Blocking**: The key difference from traditional QC - we trust the requester AI to read and adapt based on the review. The reviewer AI's work is respected by ensuring it's always displayed and read.

---

**End of FINAL Plan (Respecting Reviewer AI's Work)**
