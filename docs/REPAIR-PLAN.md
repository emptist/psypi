# REPAIR-PLAN.md - Fix psypi from good branch

## Current State (good branch - commit 626ab61)

✅ **Working:**
- `psypi-tasks` tool (line 193)
- `psypi-stats` tool (line 600)
- 30 Pi tools registered
- `gleam build` works (0.16s)

❌ **Broken in continue/buggy:**
- `psypi-stats` deleted by `fedab7d`
- `psypi-tasks` removed by `a61c97e`
- Duplicate `psypi-skill-load` registrations

---

## Repair Steps

### 1. Stay on good branch
```bash
git checkout good
```

### 2. Cherry-pick ONLY this clean commit:
```bash
git cherry-pick a4ea5c2
# This fixes skill.gleam JSONB→text casting
```

### 3. Run Gleam build
```bash
cd gleam/psypi_core && gleam build
```

### 4. Test Pi tools (via psypi)
```bash
# Test psypi-tasks
psypi "run psypi-tasks tool"

# Test psypi-stats
psypi "run psypi-stats tool"
```

### 5. Add fresh psypi-skill-load manually
**DO NOT copy from buggy commits!**

Create NEW tool in extension.js (add after psypi-skill-show):
```javascript
// psypi-skill-load tool (Database-First Skill System - Step 3)
pi.registerTool({
  name: "psypi-skill-load",
  description: "Load skill content from DB to .pi/skills/",
  parameters: { name: { type: "string" } },
  async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
    try {
      const result = await skill_get(params.name);
      const skillResult = unwrapGleamResult(result);
      if (!skillResult.ok) {
        return { content: [{ type: "text", text: `Error: ${skillResult.error}` }] };
      }
      const fs = await import('fs');
      const path = await import('path');
      const skillDir = path.join(process.cwd(), '.pi', 'skills', params.name);
      fs.mkdirSync(skillDir, { recursive: true });
      if (skillResult.value.content) {
        fs.writeFileSync(path.join(skillDir, 'SKILL.md'), skillResult.value.content);
        return { content: [{ type: "text", text: `Loaded! Saved to ${skillDir}/SKILL.md` }] };
      }
      return { content: [{ type: "text", text: `No content in DB` }] };
    } catch (err) {
      return { content: [{ type: "text", text: `Error: ${err.message}` }] };
    }
  }
});
```

### 6. Verify no duplicates
```bash
grep -c 'psypi-skill-load\|psypi-tasks\|psypi-stats' src/agent/extension/extension.js
```
Should show: 1 each (no duplicates!)

---

## Forbidden (causes bugs!)

- ❌ Do NOT cherry-pick `fedab7d` (breaks psypi-stats)
- ❌ Do NOT cherry-pick anything from buggy branch
- ❌ Do NOT edit lines 193-600 of extension.js (working tools!)
- ❌ Do NOT copy psypi-skill-load from other commits

---

## Commit after repair:
```bash
git add -A && git commit -m "fix: Repair Pi tools, add psypi-skill-load (clean)"
```

---

**Good luck!** 🍀