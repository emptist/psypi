-- 029f_sbot_qc_cross_reference.sql
-- QC: Cross-reference S-bot findings (ab6e34f0, a4300fec) with my verified findings
-- Verify each S-bot confirmed finding, mark agreements/disagreements

-- ============================================================
-- S-BOT FINDING AGREEMENT ANALYSIS
-- ============================================================

-- #1: project_id is raw String everywhere — no type-safe ProjectId wrapper
-- VERDICT: AGREE. No ProjectId type exists. All project_id values are raw String.
-- But this is a design improvement, not a bug. Downgrade from high to medium.
UPDATE review_findings SET status = 'confirmed', description = description || ' QC: Verified — no ProjectId wrapper type exists. All project_id handled as String. This is a design gap, not a runtime bug. Related to #291 (no Project.resolve).'
WHERE review_id = 'ab6e34f0-8f42-46b6-930f-51bbb156d232' AND finding_number = 1;

-- #2: areflect.save_issue omits project_id — already confirmed in my review as finding #2
-- VERDICT: AGREE. Already confirmed.

-- #3: No code updates agent_sessions.last_heartbeat — already confirmed as finding #3
-- VERDICT: AGREE. Already confirmed. But S-bot correctly notes ctx_is_idle is primary check.

-- #4: A-bot wakeup chain 4 sequential failures — already confirmed as finding #4
-- VERDICT: AGREE. Already confirmed.

-- #5: inter_review list/get queries fail — already confirmed as finding #5
-- VERDICT: AGREE. Already confirmed.

-- #8: a_orchestrator never writes inter-review response to DB
-- VERDICT: AGREE. VERIFIED: DB has respond_to_inter_review() function but NO Gleam code calls it.
-- tool_commit.gleam only reads overall_score, never writes the review response.
-- This means tool_commit permanently waits for a review that can never be completed.
UPDATE review_findings SET status = 'confirmed', description = description || ' QC: VERIFIED — psql shows respond_to_inter_review() and update_inter_review() exist as DB functions, but grep for these in *.gleam returns zero results. tool_commit.gleam only reads overall_score from inter_reviews, never calls respond_to_inter_review(). The commit workflow is permanently stuck at phase 2.'
WHERE review_id = 'ab6e34f0-8f42-46b6-930f-51bbb156d232' AND finding_number = 8;

-- #9: Inter-review commit flow stuck — missing git add before git commit
-- S-bot already retracted this. VERDICT: AGREE with retraction.
-- git commit -a or separate git add is not required if files are already staged.

-- #10: semantic_id uses is_idle for A/S prefix — idle S-agent gets wrong identity
-- VERDICT: AGREE. VERIFIED: agent_identity.gleam:63 `let prefix = case ctx.is_idle { True -> "A" False -> "S" }`
-- An idle S-agent would get "A-" prefix, which is semantically wrong.
-- However, the semantic_id is used for DISPLAY, not for access control. Still a logic error.
UPDATE review_findings SET status = 'confirmed', description = description || ' QC: VERIFIED — agent_identity.gleam:63 shows prefix = case ctx.is_idle { True -> "A" False -> "S" }. An idle S-agent gets "A-" prefix. This is a semantic mismatch but not a security issue since prefix is used for display/identity, not access control.'
WHERE review_id = 'ab6e34f0-8f42-46b6-930f-51bbb156d232' AND finding_number = 10;

-- #11: memory.search references saved_at — S-bot already retracted. AGREE.

-- #12: memory.save() uses full memory_decoder on RETURNING id
-- VERDICT: AGREE. VERIFIED: memory.gleam:76 `RETURNING id` returns only 1 column,
-- but line 81 uses memory_decoder() which expects 7 columns (id, content, tags, source, agent_id, importance, created_at).
-- Decode will fail because row only has `id`. save() always reports DecodeError.
UPDATE review_findings SET status = 'confirmed', description = description || ' QC: VERIFIED — memory.gleam:76 RETURNING id returns 1 column, but line 81 decode.run(row, memory_decoder()) expects 7 columns. The decode fails with missing fields. Every memory.save() call returns Error(DecodeError).'
WHERE review_id = 'ab6e34f0-8f42-46b6-930f-51bbb156d232' AND finding_number = 12;

-- #13-#16: Type mismatches — S-bot already retracted/marked duplicate. AGREE.

-- #17: Systematic missing ::text casts — duplicate of my #5. AGREE.

-- #18: seed.gleam multi-statement SQL — duplicate. AGREE.

-- #19: psypi-doc-save declares only file_path param but uses 5 args
-- VERDICT: AGREE. VERIFIED: code_version.gleam:144 params: [string_param("file_path")]
-- but args has 5 entries: file_path, content, saved_by, commit_hash, reason.
-- Pi tool framework generates UI from params, so only file_path is available to the user.
UPDATE review_findings SET status = 'confirmed', description = description || ' QC: VERIFIED — code_version.gleam:144 PiToolCall params has only string_param("file_path"), but args uses 5 parameters. The Pi tool framework generates the tool UI from params, so content/saved_by/commit_hash/reason are never provided by the user. Doc saves always have empty content.'
WHERE review_id = 'ab6e34f0-8f42-46b6-930f-51bbb156d232' AND finding_number = 19;

-- #20: psypi-my-id lit() missing project and global fields
-- VERDICT: AGREE. VERIFIED: agent_identity.gleam:268 lit() constructs
-- { is_idle, source, model, thinking_level, cwd } but IdentityContext also needs project and global.
-- get_enriched_identity() computes project and _global from cwd but never updates ctx before calling semantic_id(ctx).
-- So ctx.project="" and ctx.global=False in semantic_id(), producing wrong IDs like "A--provider-model".
UPDATE review_findings SET status = 'confirmed', description = description || ' QC: VERIFIED — agent_identity.gleam:268 lit() omits project and global. get_enriched_identity():185 computes project and _global but passes original ctx to semantic_id(). ctx.project="" and ctx.global=False produce malformed IDs like "A--provider-model".'
WHERE review_id = 'ab6e34f0-8f42-46b6-930f-51bbb156d232' AND finding_number = 20;

-- #21: Error(_) -> Ok(default) silently swallows decode errors — already confirmed. AGREE.

-- #22: a_db_reader.read_open_issues uses status=closed — already confirmed. AGREE.

-- #23: No connection pooling — already confirmed. AGREE.

-- #24-#26: Already confirmed critical findings. AGREE.

-- #27: DB heartbeat check is architecturally redundant
-- VERDICT: AGREE. VERIFIED: ctx_is_idle(ctx) is the primary idle check.
-- is_s_still_idle() queries agent_sessions.last_heartbeat which is never updated (finding #3).
-- The DB check is a dead code path that always returns True.
UPDATE review_findings SET status = 'confirmed', description = description || ' QC: VERIFIED — is_s_still_idle() always returns True because last_heartbeat is never updated (finding #3). ctx_is_idle is the primary check per user confirmation. The DB heartbeat check is dead code.'
WHERE review_id = 'ab6e34f0-8f42-46b6-930f-51bbb156d232' AND finding_number = 27;

-- #28: set_config/get_config use in-memory JS object while psypi_config.gleam uses DB
-- VERDICT: AGREE. VERIFIED: pi_extension_ffi.mjs get_config returns _configStore[key] || null (in-memory),
-- while psypi_config.gleam reads from psypi_config table (DB). Two separate config stores never sync.
UPDATE review_findings SET status = 'confirmed', description = description || ' QC: VERIFIED — pi_extension_ffi.mjs:153 get_config returns _configStore[key] || null (in-memory JS object). psypi_config.gleam reads from psypi_config table (PostgreSQL). Two config stores with no synchronization mechanism.'
WHERE review_id = 'ab6e34f0-8f42-46b6-930f-51bbb156d232' AND finding_number = 28;

-- ============================================================
-- S-BOT FINDINGS IN a4300fec (project_id Repair Plan review)
-- These are mostly duplicates of my findings from 028a-028i
-- ============================================================

-- #288-#297: S-bot cross-reference findings (027p) — already merged into my review
-- These are duplicates of my confirmed findings. Mark as duplicate.
UPDATE review_findings SET status = 'duplicate'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837'
  AND finding_number IN (288, 289, 290, 291, 292, 293, 294, 295, 296, 297);

-- #355-#414: My findings from 028a-028i — already verified in 029a-029e
-- No action needed, these are my own findings.

-- ============================================================
-- NEW FINDING FROM QC: get_enriched_identity computes but discards project/global
-- ============================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837',
  415, 'high', 'logic_error', 'agent_identity',
  'get_enriched_identity computes project/global but passes original ctx to semantic_id — computed values discarded',
  'agent_identity.gleam:185-188 computes project=resolve_project(ctx.cwd) and _global=check_git_exists(ctx.cwd), but then calls semantic_id(ctx) with the ORIGINAL ctx that has project="" and global=False. The computed values are never used. This means semantic_id always sees empty project and False global, producing malformed IDs like "A--provider-model" instead of "A-psypi-provider-model".',
  'agent_identity.gleam:185 let project = resolve_project(ctx.cwd); line 187 let _global = check_git_exists(ctx.cwd); line 189 case semantic_id(ctx) — ctx is unchanged. The variables project and _global are computed but never applied to ctx.',
  'confirmed'
);

-- ============================================================
-- QC VERIFICATION SUMMARY
-- ============================================================
SELECT 'S-BOT QC CROSS-REFERENCE SUMMARY' AS section;
SELECT 'S-bot confirmed findings verified' AS category, COUNT(*) AS cnt
FROM review_findings
WHERE review_id IN ('ab6e34f0-8f42-46b6-930f-51bbb156d232', 'a4300fec-553a-49cd-bd1b-fe5ee5e21b6d')
  AND status = 'confirmed';

SELECT 'My retractions verified correct' AS category;
SELECT 'New finding from QC: #415' AS category;

SELECT '=== ALL FINDINGS BY STATUS ===' AS section;
SELECT status, COUNT(*) AS cnt
FROM review_findings
GROUP BY status
ORDER BY cnt DESC;
