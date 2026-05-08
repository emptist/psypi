# Adding a Skill the Pi‑official Way

## Quick Overview
Pi expects every skill to live under:
```
<project‑root>/.pi/skills/<skill‑identifier>/SKILL.md
```
The **folder name (`<skill‑identifier>`) must be identical to the `name` field inside `SKILL.md`**. If they differ, Pi marks the skill as *conflicted* and will not load it.

---
### 1. Create the folder (the identifier)
```bash
# Example identifier "build-iphone-apps"
mkdir -p .pi/skills/build-iphone-apps
```
The folder name becomes the public identifier used by all Pi tools (e.g., `psypi build-iphone-apps …`).

---
### 2. Write `SKILL.md` inside that folder
A minimal, **valid** `SKILL.md` must contain the mandatory keys:

```markdown
name "build-iphone-apps"
description "Build native iOS apps from Swift sources using the CLI‑only toolchain."
location "./SKILL.md"
```
* `name` – **must match the folder name exactly**.
* `description` – short one‑sentence summary.
* `location` – usually `"./SKILL.md"` (relative to the file itself).

Optional keys you may add:
```
version "0.1.0"
tags ["ios","swift","cli"]
```
Do **not** include unknown top‑level keys – they are ignored and can cause future parsing warnings.

---
### 3. Add the implementation (optional)
If the skill provides a tool, hook, prompt, or script, reference the file inside `SKILL.md`:
```
tool "./tool.ts"    # registers a Pi tool via pi.registerTool()
hook "./hook.ts"    # registers event listeners via pi.on(...)
prompt "./prompt.md"
script "./run.sh"   # executable Bash script
```
Only add the keys you actually need.

---
### 4. Verify the skill works
1. **Reload the catalog**
   ```bash
   psypi tools list      # or psypi skills list
   ```
   If the skill appears without a *conflict* warning, the naming is correct.
2. **Test a tool** (if you added one)
   ```bash
   psypi <skill‑identifier> <tool‑name> --help
   ```
3. **Run the built‑in validator**
   ```bash
   psypi skill validate .pi/skills/<skill‑identifier>
   ```
   It will flag missing required fields or name mismatches.

---
### 5. Keep the folder tidy
* One `SKILL.md` per folder – no nested skill folders.
* Never rename the folder without also updating the `name` field (or delete & recreate). A mismatch produces the *conflict* warning you saw.
* Identifiers must be **unique** across the entire `.pi/skills` tree.

---
## Quick “Do‑It‑Yourself” Template
```bash
# 1️⃣ Create the folder
mkdir -p .pi/skills/<identifier>

# 2️⃣ Write the SKILL.md (replace placeholders)
cat > .pi/skills/<identifier>/SKILL.md <<'EOF'
name "<identifier>"
description "One‑sentence description of what the skill does."
location "./SKILL.md"
# optional extra keys:
# version "0.1.0"
# tags ["example","demo"]
EOF
```
If you need a tool, add `tool.ts` and reference it:
```bash
cat > .pi/skills/<identifier>/tool.ts <<'EOF'
export default function (pi) {
  pi.registerTool({
    name: "run",
    description: "Run the <identifier> helper",
    execute: async (ctx, args) => {
      console.log("Running <identifier> with", args);
    },
  });
}
EOF
#   tool "./tool.ts"
```
Run `psypi skills list` again – the skill should appear with no warnings.

---
## TL;DR Checklist
| ✅ Done? | Action |
|---|---|
| ✅ | Folder created under `.pi/skills/` – name = identifier |
| ✅ | `SKILL.md` exists inside that folder |
| ✅ | `name` field **exactly** matches the folder name |
| ✅ | Required fields (`description`, `location`) are present |
| ✅ | Optional implementation files (tool, hook, script) are referenced correctly |
| ✅ | `psypi skills list` shows the skill – no *conflict* warnings |
| ✅ | (Optional) `psypi skill validate …` passes |

Follow these steps for any new skill, and Pi will load it without conflicts.
