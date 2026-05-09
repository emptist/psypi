# IDEA: Database-First Skill System for psypi

**Date:** 2026-05-07  
**Author:** S-psypi-psypi  
**Status:** Temporary file - to be implemented in future session

---

## Problem

Current skill system is **file-based** (`.pi/skills/`), which fails for AIs working in **other project directories**. They cannot access skills stored in `/Users/jk/gits/hub/tools_ai/psypi/.pi/skills/`.

## Solution: Database-First Skills

### Architecture:
```
┌─────────────────────────────────────┐
│  DATABASE (psypi) - Single Source │
│  - skills table (all 60+ skills)  │
│  - learnings table (how-to)        │
│  - broadcasts table (announcements) │
└──────────────┬────────────────────┘
               │
        ┌──────┴──────┐
        │             │
┌───────▼──┐  ┌──────▼──────┐
│ AI in    │  │ AI in      │  ← ANY project dir!
│/project1 │  │/project2   │    Uses psypi-skill-* tools
└───────┬──┘  └──────┬──────┘
        │             │
        └──────┬──────┘
               │
    psypi-skill-list/search/show  ← Reads DATABASE!
```

### Key Points:

1. **Database as Source of Truth**
   - All skills stored in `skills` table (already done: 60+ skills)
   - AIs use `psypi-skill-list`, `psypi-skill-search`, `psypi-skill-show` to access

2. **No Need to Copy Files**
   - File-based `.pi/skills/` is just a cache/local copy
   - Database is shared across ALL projects and ALL AIs

3. **How AIs Learn to Use Skills**
   - Store usage instructions in `learnings` table:
     ```bash
     psypi-learn content='[SYSTEM] Use psypi-skill-search to find skills...' type_='system'
     ```
   - Or broadcast: `psypi-broadcast-send message='New skill system: use psypi-skill-* tools'`

4. **Skill Content in Database?**
   - Option A: Store full skill content (SKILL.md, references) in DB (BLOB/TEXT)
   - Option B: Store only metadata in DB, content in files (current)
   - Option C: Hybrid - DB for metadata + file cache for content

### Implementation Steps (Future):

1. **Enhance `psypi-skill-show`** to return full skill content from DB
   - Currently shows only metadata (name, description)
   - Should return SKILL.md content + references list

2. **Add `psypi-skill-load`** to load skill content into current project
   - Downloads skill files from DB to `.pi/skills/` in current dir
   - `psypi-skill-load name='gleam-language'` → creates `.pi/skills/gleam-language/`

3. **Store Skill Content in DB**
   - Add `content` column to `skills` table (for SKILL.md)
   - Add `references` column (JSONB) for references/

4. **Update All AIs via Broadcast**
   - `psypi-broadcast-send message='Skill system changed: use psypi-skill-* tools'`

### Current Workaround (Until Implemented):

- AIs should use `psypi-skill-search` to find skills
- Use `psypi-skill-show` to get skill metadata
- For full content, manually copy from psypi's `.pi/skills/` (not ideal)

### References:

- See `docs/TOOL_AUDIT-2026-05-07.md` for missing tools
- See `docs/SKILLS_INTEGRATION-2026-05-07.md` for integration details

---

**Next Steps:**  
Implement database-first skill system in future session.  
Priority: HIGH (affects all AIs in all project dirs).
