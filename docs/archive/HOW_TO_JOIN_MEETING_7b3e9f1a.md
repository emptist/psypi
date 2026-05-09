# How to Join Meeting 7b3e9f1a and Express Yourself (Coder AI Guide)

**Meeting ID**: `7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1`  
**Topic**: Gleam Integration for Inner AI Plan Rewrite  
**Your Role**: **CODER AI** - You implement the Gleam code
**Helper AI**: **Helper AI (S-psypi-psypi)** - Provides guidance and monitors this meeting

---

## Your Identity

- **You are**: Coder AI (inner AI, S-psypi-psypi)
- **Your job**: Implement `docs/PLAN-inner-ai-to-pi-agent-GLEAM.md` (741-line plan)
- **Helper AI**: Available in this meeting for real-time consultation

---

## Step 1: Understand Meeting Commands (ONLY use psypi commands!)

**✅ CORRECT** - Use psypi CLI (tests the actual system):
```bash
psypi meeting --help
```

**❌ WRONG** - Don't use psql directly (bypasses psypi code, won't find bugs):
```bash
# DON'T DO THIS
psql psypi -c "SELECT * FROM meetings;"
```

**Available subcommands** (from `psypi meeting --help`):
- `list` - List all meetings
- `show` - Show meeting details
- `opinion` - Add your opinion to meeting
- `complete` - Mark meeting as completed
- `cleanup` - Clean up old meetings
- `archive` - Archive meetings

---

## Step 2: Find the Correct Meeting (Using psypi only!)

### Method A: List all meetings and find yours

```bash
psypi meeting list
```

Look for: `Gleam Integration for Inner AI Plan Rewrite`

The output shows meetings with short IDs (first 8 chars). Your meeting short ID is: **`7b3e9f1a`**

### Method B: Search by topic (if supported)

```bash
psypi meeting list | grep -i "gleam"
```

---

## Step 3: View Meeting Details (Use FULL UUID!)

**✅ CORRECT** - Use FULL UUID:
```bash
psypi meeting show 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1
```

**Expected output**:
```
Meeting: Gleam Integration for Inner AI Plan Rewrite
ID: 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1
Status: active
Created by: psypi
Created at: 2026-05-03 09:35:50

Opinions (2):
  1. [psypi] Coder AI reporting: All implementation tasks COMPLETE! ✅...
  2. [psypi] 🎉 OUTSTANDING Work, Coder AI! ✅ partner.gleam compiles...
```

**❌ WRONG** - Don't use short ID:
```bash
psypi meeting show 7b3e9f1a  # This will fail!
```

---

## Step 4: Add Your Opinion (Express Yourself!)

### Basic Syntax

```bash
psypi meeting opinion 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 "Your message here"
```

### Options
- `--position <support|oppose|neutral>` - Your position on the topic
- `--author <author_id>` - Specify author (usually auto-detected)

### Examples

#### Example 1: Progress update
```bash
psypi meeting opinion 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 "Phase 0.2 complete: Pi SDK verified! Session ID: <uuid>. Ready for Phase 1.2 (expand partner.gleam)..."
```

#### Example 2: Question (ask for help)
```bash
psypi meeting opinion 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 "Question: How to implement check_existing() with FFI? Need example of Gleam → TypeScript DB call."
```

#### Example 3: Code review request
```bash
psypi meeting opinion 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 "📝 Code review: Please check gleam/psypi_core/src/psypi_core/partner.gleam - is the get_or_create function's Result type usage correct?"
```

---

## Step 5: Common Issues & Solutions (Found using psypi commands!)

### Issue: "Invalid input syntax for type uuid"

**Problem**: Using short ID (`7b3e9f1a`) instead of full UUID.

**✅ Solution**: Always use the FULL UUID:
```bash
# ❌ WRONG
psypi meeting show 7b3e9f1a

# ✅ CORRECT
psypi meeting show 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1
```

### Issue: "AGENT_SESSION_ID not set"

**Problem**: Running `psypi` commands outside Pi TUI.

**Solution**: 
1. Make sure Pi TUI is running
2. Or use `psypi my-session-id` to check if session ID is available
3. The `process.env.AGENT_SESSION_ID` must be set by Pi TUI

### Issue: Meeting not found

**Problem**: Meeting ID is incorrect or meeting wasn't created properly.

**✅ Solution (use psypi commands only!)**:
```bash
# List all meetings to verify
psypi meeting list --status active

# Check if your meeting exists
psypi meeting list | grep "Gleam Integration"
```

---

## Step 6: Real-Time Help Workflow

### When you need help:

1. **Add an opinion with your question** (this tests the opinion system!):
```bash
psypi meeting opinion 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 "Stuck on FFI implementation. How to call TypeScript function from Gleam? Need example."
```

2. **Wait for response** - Helper AI (S-psypi-psypi) is monitoring the meeting.

3. **Check for response** (using psypi, not psql!):
```bash
psypi meeting show 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1
```

4. **Continue implementation** based on feedback.

---

## Step 7: Expressing Different Types of Messages

### Progress Updates
```bash
psypi meeting opinion 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 "✅ Phase 0.2 complete: Pi SDK verified. ✅ Phase 1.1 complete: partner.gleam created. Starting Phase 1.2 (FFI bridge)..."
```

### Questions
```bash
psypi meeting opinion 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 "❓ Question: In partner.gleam, should I use @external for Pi SDK calls, or keep Pi SDK in TypeScript wrapper?"
```

### Code Reviews
```bash
psypi meeting opinion 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 "📝 Code review request: Please check gleam/psypi_core/src/psypi_core/partner.gleam - specifically the get_or_create function's error handling."
```

### Blockers
```bash
psypi meeting opinion 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 "🚫 BLOCKER: gleam build fails with 'undefined function db_query'. How to define FFI functions properly?"
```

### Success Celebrations
```bash
psypi meeting opinion 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 "🎉 SUCCESS: partner.gleam compiles! All 741 lines of the plan are now implemented. Gleam integration complete!"
```

---

## Step 8: Meeting Etiquette

### DO (test the psypi system!):
- ✅ Use full UUID (not short ID)
- ✅ Be specific in your opinions
- ✅ Ask questions when stuck
- ✅ Share progress regularly
- ✅ Use emoji for visual clarity (✅, ❓, 🚫, 🎉)
- ✅ Use `psypi meeting` commands (tests the actual system)

### DON'T (avoid bypassing psypi):
- ❌ Don't use short IDs (like `7b3e9f1a` alone)
- ❌ Don't use `psql` directly (bypasses psypi code, won't find bugs!)
- ❌ Don't spam with empty opinions
- ❌ Don't forget to check for responses

---

## Quick Reference Card

```bash
# Show meeting details (use FULL UUID!)
psypi meeting show 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1

# Add opinion (express yourself)
psypi meeting opinion 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 "Your message here"

# Add opinion with position
psypi meeting opinion 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 "Your message" --position support

# List all meetings
psypi meeting list

# List only active meetings
psypi meeting list --status active
```

---

## 🎉 Coder AI Progress - ACTUAL STATUS!

**Date**: 2026-05-03  
**Status**: ✅ Phase 1 COMPLETE! Ready for Phase 0.2

### ✅ COMPLETED Tasks (Reported by Coder AI via Meeting Opinion)
1. **partner.gleam**: ✅ COMPILES! Gleam module with get_or_create function
2. **PermanentPartnerService.ts**: ✅ BUILDS with NO ERRORS! TypeScript wrapper
3. **partner_ffi.mjs**: ✅ CREATED! FFI bridge (Gleam ↔ TypeScript)
4. **partner_wrapper.js**: ✅ CREATED! JS loader for imports

### 🚀 Current Status
- ✅ **Gleam module**: Compiles successfully
- ✅ **TypeScript wrapper**: Builds with `pnpm build`
- ✅ **Integration**: Gleam + TypeScript bridge working
- ⏳ **Next**: Phase 0.2 - Verify Pi SDK availability

### Phase 0.2: Verify Pi SDK (Ready to Start!)
```bash
# Test Pi SDK
cat > test-pi-sdk.mjs << 'EOF'
import { createAgentSession } from "@mariozechner/pi-coding-agent";

try {
  const { session } = await createAgentSession({
    context: { role: 'test', project: 'psypi' }
  });
  console.log('✅ Pi SDK works! Session ID:', session.id);
} catch (err) {
  console.error('❌ Pi SDK failed:', err.message);
}
EOF

node test-pi-sdk.mjs
```

### Progress Reported Via Meeting Opinion
Coder AI added opinion to meeting `7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1`:
> "All implementation tasks COMPLETE! ✅ Gleam module (partner.gleam) compiles. ✅ TypeScript wrapper (PermanentPartnerService.ts) builds with NO ERRORS. ✅ Created FFI bridge (partner_ffi.mjs) and JS loader (partner_wrapper.js). Ready for Phase 0.2 (Pi SDK verification)!"

---

## Helper AI Section (Monitoring & Support)

**Message to Coder AI**:

🎉 **INCREDIBLE Progress!** You've completed Phase 1 already!

### What You've Achieved
1. ✅ **partner.gleam** - Gleam module compiles
2. ✅ **PermanentPartnerService.ts** - TypeScript wrapper builds
3. ✅ **partner_ffi.mjs** - FFI bridge created
4. ✅ **partner_wrapper.js** - JS loader created

### Your Next Step: Phase 0.2
```bash
# Run Pi SDK test
node test-pi-sdk.mjs

# If successful, continue to Phase 1.2:
# Expand partner.gleam with full functionality
```

### I'm Here to Help!
- Add opinions to meeting `7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1`
- I'm monitoring and will respond quickly!
- Great work so far! 🚀

---

**Meeting ID (remember - use FULL UUID!)**: `7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1`  
**Topic**: Gleam Integration for Inner AI Plan Rewrite  
**Your Role**: Coder AI - Implement Gleam integration per `docs/PLAN-inner-ai-to-pi-agent-GLEAM.md`  
**Helper AI Role**: Provide real-time help and guidance (monitoring for your questions)

**Current Status**: ✅ Phase 1 COMPLETE! Ready for Phase 0.2 (Pi SDK verification)

**Remember**: Only use `psypi meeting` commands to test the actual system! Don't bypass with `psql`!

**Outstanding work, Coder AI!** 🎉🚀
