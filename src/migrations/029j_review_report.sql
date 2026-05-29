-- 029j_review_report.sql
-- Comprehensive review report — 140 confirmed findings
-- Generated from systematic audit of psypi codebase

-- ============================================================
-- REVIEW REPORT: psypi System Review
-- ============================================================
-- Date: 2026-05-29
-- Reviewer: emptist (A-bot) with cross-reference from S-bot reviews
-- Scope: Full codebase — 30+ Gleam modules, 3 FFI modules, 78 DB tables
-- Methodology: SQL case audit, FFI type audit, INSERT audit, decoder audit,
--   cross-reference with S-bot reviews ab6e34f0 and a4300fec

-- ============================================================
-- EXECUTIVE SUMMARY
-- ============================================================
-- 140 confirmed findings across 25+ modules
-- 16 CRITICAL: System is non-functional in multiple areas
-- 41 HIGH: Major features broken or data integrity at risk
-- 61 MEDIUM: Design flaws, missing features, structural gaps
-- 21 LOW: Minor issues, missing parameters, data quality
-- 1 COSMETIC: Verification artifact

-- ============================================================
-- TOP 5 CRITICAL FINDINGS (must fix first)
-- ============================================================
-- #419: get_config FFI returns null instead of undefined — breaks ALL Option(String) matching
-- #420: monitor_ai.auto_file_issue() uses 3 non-existent columns — INSERT always fails
-- #421: areflect.save_issue() missing project_id — INSERT always fails
-- #413: inter_review requested_at decoded as String — node-postgres returns Date objects
-- #3: No code updates agent_sessions.last_heartbeat — is_s_still_idle always True

-- ============================================================
-- ROOT CAUSES (3 categories)
-- ============================================================
-- 1. FFI TYPE MISMATCHES: get_config returns null, timestamptz decoded as String
--    Affects: hook_on_agent_end, inter_review, agent_identity
--    Fix: Change FFI to return undefined for None, add ::text casts for timestamptz
--
-- 2. MISSING project_id: Multiple INSERT statements omit NOT NULL project_id
--    Affects: areflect, monitor_ai
--    Fix: Add project_id parameter to all INSERT functions
--
-- 3. SQL CASE MISMATCHES: monitor_ai uses UPPERCASE for lowercase-constrained columns
--    Affects: monitor_ai (skills.status, inter_reviews.status)
--    Fix: Change 'PENDING'/'FAILED' to 'pending'/'failed' in monitor_ai queries

-- ============================================================
-- MODULES BY FINDING COUNT (top 10)
-- ============================================================
-- pi_extension_ffi: 11 findings (1 critical, 4 high, 5 medium, 1 low)
-- monitor_ai:       10 findings (2 critical, 3 high, 4 medium, 1 low)
-- a_db_reader:       9 findings (1 critical, 4 high, 3 medium, 1 low)
-- schema:            8 findings (0 critical, 3 high, 4 medium, 1 low)
-- multiple:          7 findings (2 critical, 3 high, 2 medium)
-- areflect:          7 findings (2 critical, 2 high, 2 medium, 1 low)
-- agent_identity:    7 findings (0 critical, 3 high, 4 medium)
-- inter_review:      5 findings (2 critical, 3 high)
-- memory:            5 findings (0 critical, 3 high, 2 medium)
-- db:                4 findings (0 critical, 2 high, 1 medium, 1 low)

-- ============================================================
-- S-BOT REVIEW QC
-- ============================================================
-- S-bot review ab6e34f0 (36 findings): 28 correct, 4 retracted (3 correct, 1 error)
-- S-bot review a4300fec (69 findings): 27 correct, 42 duplicates (1 error: #382)
-- S-bot quality: HIGH — only 2 minor errors in 105 findings
-- Error 1: #9 retraction too aggressive (should downgrade, not retract)
-- Error 2: #382 incorrectly marked duplicate (unique finding about inter_reviews.status)

-- ============================================================
-- CASE CONVENTION REFERENCE
-- ============================================================
-- UPPERCASE status values: tasks, projects
-- lowercase status values: skills, inter_reviews, issues, meetings, system_reviews,
--   event_hooks, agent_sessions, review_findings, prompt_suggestions, dead_letter_queue,
--   process_pids, issue_events
-- No status constraint: provider_api_keys, project_communications

-- ============================================================
-- RECOMMENDED FIX PRIORITY
-- ============================================================
-- Phase 1 (Critical — system non-functional):
--   1. Fix get_config FFI: return undefined instead of null
--   2. Fix monitor_ai.auto_file_issue(): correct column names + add project_id
--   3. Fix areflect.save_issue(): add project_id parameter
--   4. Fix inter_review decoder: add ::text casts for uuid/timestamptz
--   5. Fix agent_sessions heartbeat: add UPDATE to hook_on_agent_end
--
-- Phase 2 (High — data integrity):
--   6. Fix monitor_ai case mismatches: 'PENDING'→'pending', 'FAILED'→'failed'
--   7. Fix memory.save() decoder: use id_decoder instead of memory_decoder
--   8. Fix agent_identity.get_enriched_identity(): apply project/global to ctx
--   9. Fix broadcast.stats(): remove status column, fix priority comparison
--   10. Fix seed.gleam: split multi-statement SQL into separate queries
--
-- Phase 3 (Medium — design improvements):
--   11. Deduplicate semantic_id() across agent_identity modules
--   12. Add project_id to areflect.save_task() and save_learning()
--   13. Add Gleam types for DB enum columns (SkillStatus, ReviewStatus, etc.)
--   14. Standardize case conventions across all tables

-- Verify final count
SELECT 'REVIEW REPORT: 140 CONFIRMED FINDINGS' AS summary;
SELECT severity, COUNT(*) AS cnt FROM review_findings WHERE status = 'confirmed' GROUP BY severity ORDER BY severity;
