---
name: troubleshoot-tool-blocked
description: Diagnose and resolve "tool execution blocked" messages in AI agent systems, particularly in the Psypi environment, by identifying root causes such as missing functions, database schema mismatches, import issues, and providing step-by-step resolution steps.

---
<objective>
This skill helps users troubleshoot when AI agent tools are blocked by the system, returning messages like "tool execution blocked". It provides a structured approach to diagnose the root cause—whether it's due to undefined functions in extensions, database schema mismatches, import/export issues, or configuration problems—and apply appropriate fixes. The skill is tailored for the Psypi system but includes general principles applicable to similar agent frameworks.
</objective>

<quick_start>
When you encounter a "tool execution blocked" message:

1. Check the specific tool that was blocked (e.g., bash, edit, write)
2. Look for recent error logs or system messages indicating undefined functions or database errors
3. Verify the system state: check if extension.js was recently generated, look at recent issues in the Psypi issue tracker
4. Apply fixes based on common patterns: regenerate extension.js, fix database schema, or resolve import aliases
</quick_start>

<context>
In systems like Psypi, tool execution is governed by extension.js which is generated from Gleam code. When a tool call is intercepted by a hook (e.g., tool_event hook) and returns { block: true }, the tool execution is blocked. Common causes include:
- Undefined functions in the generated JavaScript (e.g., missing function due to incorrect import aliasing)
- Database schema mismatches (missing columns or tables)
- Import/export issues in the Gleam-to-JS generation process
- Configuration mismatches (wrong database connection)
The Psypi system tracks these as issues; checking recent issues can provide clues.
</context>

<workflow>
## Step 1: Identify the Blocked Tool and Error Context
- Determine which tool was blocked (e.g., bash, edit, write, psypi-* commands)
- Note the exact error message or response (often includes details like "function undefined" or "column does not exist")
- Check if this occurred after a recent code change, update, or system restart

## Step 2: Examine System Logs and Recent Issues
- Run `psypi-issues` to see recent issues, especially those related to the blocked tool or system components
- Look for issues with titles like "Undefined function", "database schema mismatch", "import aliasing", or specific to the blocked tool
- Check system health: `psypi-autonomic-health` and `psypi-autonomic-alerts` for any flags

**B. Database Schema Mismatches**
- Look for errors like "column X does not exist in table Y"
- Run database migrations or check schema: psql -d psypi -c "\d table_name"
- Common missing columns: created_by in issues table
- Apply fixes: alter table to add missing columns if needed

**C. Import/Aliasing Problems**
- Check if the issue is related to function aliasing in extension_generator.gleam (e.g., get_resolved_identity mapped to agent_identity_get_resolved_identity)
- Verify that the alias matches what the Gleam code exports
- Consider switching to namespace imports if aliasing is fragile

**D. Configuration/Connection Issues**
- Verify database connection settings (PSYPI_DB_NAME environment variable)
- Ensure the system is connecting to the correct database (psypi vs legacy names)

## Step 5: Apply Fixes and Test
Depending on the diagnosed cause:
- For undefined functions: Fix the Gleam code, recompile, regenerate extension.js, then test the tool
- For schema issues: Run necessary SQL migrations, then test
- For import issues: Correct the aliasing in extension_generator.gleam, regenerate extension.js
- For configuration: Set correct environment variables or config files

After applying fixes, test the blocked tool again to confirm it works.

## Step 6: Verify Resolution and Document
- Confirm the tool no longer returns a blocked message
- Check that the tool performs its intended function
- Optionally, document the fix or create a issue to prevent recurrence
</workflow>

<success_criteria>
This troubleshooting process is complete when:
- [ ] The blocked tool executes successfully without returning a blocked message
- [ ] The root cause has been identified and addressed
- [ ] System health checks show no related errors or alerts
- [ ] The extension.js is correctly generated and contains all required functions
- [ ] Database schema is consistent with application expectations
</success_criteria>
