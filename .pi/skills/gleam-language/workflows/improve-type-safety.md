# Workflow: Improve Type Safety

When adding or improving types in Gleam code, follow this workflow to maintain high quality.

## Goal

Add custom types (like AgentId) without duplicating existing types.

## Steps

### Step 1: Check Existing Types FIRST

Before creating any new ID type, check if one already exists:

```bash
# Find all ID types
grep -r "pub type.*Id" src/psypi/

# Or use glob
ls src/psypi/*_types.gleam
```

### Step 2: Reuse or Extend

- ✅ If type exists: Use it, or extend it
- ❌ If no type exists: Create new one carefully

### Step 3: Add Type with Helpers

When creating new type wrapper:

```gleam
// In module_name_types.gleam
pub type MyId { MyId(String) }

pub fn my_id(s: String) -> MyId { MyId(s) }
pub fn my_id_to_string(id: MyId) -> String {
  case id { MyId(s) -> s }
}
```

### Step 4: Update Quality Doc

Add the new type to `docs/gleam-quality-guidelines.md` so others know it exists.

### Step 5: Test Build

```bash
rm -rf build/ && gleam build
```

## Examples

### Adding AgentId (DONE)

- File: `src/psypi/agent_identity_types.gleam`
- Check: `grep -r "pub type.*Id" src/psypi/` - only AgentId exists
- Added: AgentId wrapper type with helpers

## Verification

- [ ] Checked existing types first
- [ ] No duplicate ID types created
- [ ] Build passes
- [ ] Updated docs