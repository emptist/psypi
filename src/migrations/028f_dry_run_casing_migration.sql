-- 028f_dry_run_casing_migration.sql
-- DRY RUN: Simulate CHECK constraint casing standardization
-- This script runs in a transaction and ROLLS BACK at the end
-- Strategy: DROP constraints first, then UPDATE data, then ADD new constraints
-- For functions: DROP and recreate with lowercase values

BEGIN;

-- ============================================================
-- STEP 1: Drop old CHECK constraints FIRST
-- ============================================================
ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_status_check;
ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_error_category_check;
ALTER TABLE tasks DROP CONSTRAINT IF EXISTS valid_completion;
ALTER TABLE projects DROP CONSTRAINT IF EXISTS projects_status_check;
ALTER TABLE dead_letter_queue DROP CONSTRAINT IF EXISTS dead_letter_queue_error_category_check;

-- ============================================================
-- STEP 2: Update existing data from UPPER_CASE to lowercase
-- ============================================================
UPDATE tasks SET status = LOWER(status);
UPDATE projects SET status = LOWER(status);

-- ============================================================
-- STEP 3: Add new lowercase CHECK constraints
-- ============================================================
ALTER TABLE tasks ADD CONSTRAINT tasks_status_check 
  CHECK (status = ANY (ARRAY['pending','running','completed','failed','fake_complete']));
ALTER TABLE tasks ADD CONSTRAINT tasks_error_category_check 
  CHECK (error_category = ANY (ARRAY['network','auth','timeout','server','transport','logic','resource','unknown', NULL]));
ALTER TABLE tasks ADD CONSTRAINT valid_completion 
  CHECK ((status <> 'completed') OR (result IS NOT NULL) OR (completed_at IS NOT NULL));
ALTER TABLE projects ADD CONSTRAINT projects_status_check 
  CHECK (status = ANY (ARRAY['active','inactive','archived']));
ALTER TABLE dead_letter_queue ADD CONSTRAINT dead_letter_queue_error_category_check 
  CHECK (error_category = ANY (ARRAY['network','auth','timeout','server','transport','logic','resource','unknown']));

-- ============================================================
-- STEP 4: Recreate views with lowercase values
-- ============================================================
CREATE OR REPLACE VIEW failure_statistics AS
SELECT error_category,
    count(*) AS total_failures,
    count(*) FILTER (WHERE (is_stuck = true)) AS stuck_count,
    count(*) FILTER (WHERE (watchdog_kills > 0)) AS watchdog_kills,
    avg(EXTRACT(epoch FROM (COALESCE(completed_at, now()) - created_at))) AS avg_duration_seconds,
    max(retry_count) AS max_retries,
    sum(retry_count) AS total_retries
   FROM tasks
  WHERE (status = ANY (ARRAY['failed'::text, 'completed'::text]))
  GROUP BY error_category;

CREATE OR REPLACE VIEW task_health_metrics AS
SELECT
    CASE
        WHEN (status = 'completed'::text) THEN 'success'::text
        WHEN ((status = 'failed'::text) AND (is_stuck = true)) THEN 'stuck'::text
        WHEN ((status = 'failed'::text) AND (consecutive_failures > 0)) THEN 'failed_with_retries'::text
        WHEN (status = 'failed'::text) THEN 'immediate_failure'::text
        WHEN ((status = 'running'::text) AND (is_stuck = true)) THEN 'stuck_running'::text
        ELSE 'other'::text
    END AS health_status,
    count(*) AS count,
    avg(EXTRACT(epoch FROM (COALESCE(completed_at, now()) - created_at))) AS avg_duration_seconds,
    avg(retry_count) AS avg_retries,
    avg(watchdog_kills) AS avg_watchdog_kills
   FROM tasks
  WHERE (created_at > (now() - '7 days'::interval))
  GROUP BY
    CASE
        WHEN (status = 'completed'::text) THEN 'success'::text
        WHEN ((status = 'failed'::text) AND (is_stuck = true)) THEN 'stuck'::text
        WHEN ((status = 'failed'::text) AND (consecutive_failures > 0)) THEN 'failed_with_retries'::text
        WHEN (status = 'failed'::text) THEN 'immediate_failure'::text
        WHEN ((status = 'running'::text) AND (is_stuck = true)) THEN 'stuck_running'::text
        ELSE 'other'::text
    END;

-- ============================================================
-- STEP 5: Drop and recreate functions with lowercase values
-- Must DROP first because some signatures differ
-- ============================================================

-- check_dependencies_completed: 'COMPLETED' -> 'completed'
DROP FUNCTION IF EXISTS check_dependencies_completed(uuid[]);
CREATE FUNCTION check_dependencies_completed(p_depends_on uuid[])
RETURNS boolean AS $$
  SELECT NOT EXISTS (SELECT 1 FROM tasks WHERE id = ANY(p_depends_on) AND status != 'completed');
$$ LANGUAGE sql STABLE;

-- convert_issue_to_task: 'PENDING' -> 'pending'
DROP FUNCTION IF EXISTS convert_issue_to_task(uuid, integer, text);
CREATE FUNCTION convert_issue_to_task(p_issue_id uuid, p_priority integer DEFAULT 5, p_created_by text DEFAULT 'system'::text)
RETURNS uuid AS $$
DECLARE
  v_task_id uuid; v_issue record;
BEGIN
  SELECT * INTO v_issue FROM issues WHERE id = p_issue_id;
  IF NOT FOUND THEN RETURN NULL; END IF;
  INSERT INTO tasks (title, description, priority, created_by, project_id, status)
  VALUES (v_issue.title, v_issue.description, p_priority, p_created_by, v_issue.project_id, 'pending')
  RETURNING id INTO v_task_id;
  UPDATE issues SET status = 'resolved' WHERE id = p_issue_id;
  RETURN v_task_id;
END;
$$ LANGUAGE plpgsql;

-- create_issue_from_dlq: 'NETWORK','AUTH','TIMEOUT','SERVER','TRANSPORT' -> lowercase
DROP FUNCTION IF EXISTS create_issue_from_dlq(uuid);
CREATE FUNCTION create_issue_from_dlq(p_dlq_id uuid)
RETURNS uuid AS $$
DECLARE
  v_issue_id uuid; v_dlq record;
BEGIN
  SELECT * INTO v_dlq FROM dead_letter_queue WHERE id = p_dlq_id;
  IF NOT FOUND THEN RETURN NULL; END IF;
  INSERT INTO issues (title, description, severity, issue_type, created_by, project_id)
  VALUES (
    'DLQ: ' || v_dlq.error_category || ' - ' || LEFT(v_dlq.error_message, 100),
    v_dlq.error_message || COALESCE(E'\n\nOriginal payload:\n' || v_dlq.original_payload, ''),
    CASE WHEN v_dlq.error_category IN ('network', 'timeout') THEN 'medium'
         WHEN v_dlq.error_category IN ('auth', 'server') THEN 'high'
         ELSE 'high' END,
    'bug', 'system', v_dlq.project_id
  ) RETURNING id INTO v_issue_id;
  UPDATE dead_letter_queue SET resolved = true, resolved_at = now() WHERE id = p_dlq_id;
  RETURN v_issue_id;
END;
$$ LANGUAGE plpgsql;

-- create_qc_review: 'PENDING' -> 'pending'
DROP FUNCTION IF EXISTS create_qc_review(uuid, integer);
CREATE FUNCTION create_qc_review(p_original_task_id uuid, p_priority integer DEFAULT 5)
RETURNS uuid AS $$
DECLARE v_review_id uuid;
BEGIN
  INSERT INTO inter_reviews (task_id, status, requested_at)
  VALUES (p_original_task_id, 'pending', NOW())
  RETURNING id INTO v_review_id;
  RETURN v_review_id;
END;
$$ LANGUAGE plpgsql;

-- get_blocked_tasks: 'PENDING' -> 'pending'
DROP FUNCTION IF EXISTS get_blocked_tasks();
CREATE FUNCTION get_blocked_tasks()
RETURNS TABLE(id uuid, title text, status text, depends_on uuid[]) AS $$
  SELECT t.id, t.title, t.status, t.depends_on FROM tasks t
  WHERE t.status = 'pending' AND t.depends_on IS NOT NULL
    AND array_length(t.depends_on, 1) > 0
    AND NOT check_dependencies_completed(t.depends_on);
$$ LANGUAGE sql STABLE;

-- get_failure_recommendations: 'NETWORK','AUTH','TIMEOUT','SERVER','TRANSPORT' -> lowercase
DROP FUNCTION IF EXISTS get_failure_recommendations();
CREATE FUNCTION get_failure_recommendations()
RETURNS TABLE(error_category text, recommendation text, count bigint) AS $$
  SELECT error_category,
    CASE error_category
      WHEN 'network' THEN 'Add retry logic with exponential backoff'
      WHEN 'auth' THEN 'Check API key rotation and permissions'
      WHEN 'timeout' THEN 'Increase timeout or optimize query'
      WHEN 'server' THEN 'Check server health and failover'
      WHEN 'transport' THEN 'Verify connection pool and network'
      WHEN 'logic' THEN 'Review code logic and edge cases'
      WHEN 'resource' THEN 'Check memory and disk usage'
      ELSE 'Investigate root cause'
    END AS recommendation,
    COUNT(*)::bigint AS count
  FROM tasks WHERE status = 'failed' AND error_category IS NOT NULL
  GROUP BY error_category ORDER BY count DESC;
$$ LANGUAGE sql STABLE;

-- get_project_stats: 'COMPLETED','FAILED','PENDING' -> lowercase
DROP FUNCTION IF EXISTS get_project_stats(uuid);
CREATE FUNCTION get_project_stats(p_project_id uuid)
RETURNS TABLE(metric text, value bigint) AS $$
  SELECT * FROM (
    SELECT 'total_tasks'::text, COUNT(*)::bigint FROM tasks WHERE project_id = p_project_id
    UNION ALL SELECT 'completed_tasks', COUNT(*)::bigint FROM tasks WHERE project_id = p_project_id AND status = 'completed'
    UNION ALL SELECT 'failed_tasks', COUNT(*)::bigint FROM tasks WHERE project_id = p_project_id AND status = 'failed'
    UNION ALL SELECT 'pending_tasks', COUNT(*)::bigint FROM tasks WHERE project_id = p_project_id AND status = 'pending'
    UNION ALL SELECT 'open_issues', COUNT(*)::bigint FROM issues WHERE project_id = p_project_id AND status = 'open'
  ) stats;
$$ LANGUAGE sql STABLE;

-- get_subsystem_stats: 'FAILED','COMPLETED' -> lowercase
DROP FUNCTION IF EXISTS get_subsystem_stats();
CREATE FUNCTION get_subsystem_stats()
RETURNS TABLE(subsystem text, failed_count bigint, last_failure timestamptz) AS $$
  SELECT error_category AS subsystem, COUNT(*)::bigint AS failed_count, MAX(updated_at) AS last_failure
  FROM tasks WHERE status = 'failed' AND error_category IS NOT NULL
  GROUP BY error_category ORDER BY failed_count DESC;
$$ LANGUAGE sql STABLE;

-- get_watchdog_candidates: 'RUNNING' -> 'running'
DROP FUNCTION IF EXISTS get_watchdog_candidates();
CREATE FUNCTION get_watchdog_candidates()
RETURNS TABLE(id uuid, title text, running_since timestamptz, stuck boolean) AS $$
  SELECT id, title, updated_at AS running_since, is_stuck AS stuck FROM tasks
  WHERE status = 'running' AND (updated_at < NOW() - INTERVAL '30 minutes' OR is_stuck = true)
  ORDER BY updated_at ASC;
$$ LANGUAGE sql STABLE;

-- resume_task: 'PENDING','FAILED' -> lowercase
DROP FUNCTION IF EXISTS resume_task(uuid);
CREATE FUNCTION resume_task(p_task_id uuid)
RETURNS boolean AS $$
  UPDATE tasks SET status = 'pending', retry_count = retry_count + 1, updated_at = now()
  WHERE id = p_task_id AND status = 'failed' RETURNING true;
$$ LANGUAGE sql;

-- start_task_execution: 'RUNNING','PENDING' -> lowercase
DROP FUNCTION IF EXISTS start_task_execution(uuid);
CREATE FUNCTION start_task_execution(p_task_id uuid)
RETURNS boolean AS $$
  UPDATE tasks SET status = 'running', updated_at = now()
  WHERE id = p_task_id AND status = 'pending' RETURNING true;
$$ LANGUAGE sql;

-- suggest_improvements_from_failures: 'FAILED' -> lowercase
DROP FUNCTION IF EXISTS suggest_improvements_from_failures(uuid, integer);
CREATE FUNCTION suggest_improvements_from_failures(p_project_id uuid DEFAULT NULL, p_limit integer DEFAULT 5)
RETURNS TABLE(error_category text, failure_count bigint, avg_time interval, suggested_improvement text, confidence_score float, related_pattern_id uuid, related_memory_id uuid) AS $$
BEGIN
  RETURN QUERY
  WITH recent_failures AS (
    SELECT error_category, COUNT(*) as failure_count,
      AVG(COALESCE(completed_at, now()) - created_at) as avg_time
    FROM tasks
    WHERE status = 'failed' AND error_category IS NOT NULL
      AND (p_project_id IS NULL OR project_id = p_project_id)
    GROUP BY error_category
    ORDER BY failure_count DESC
    LIMIT p_limit
  )
  SELECT
    rf.error_category,
    rf.failure_count,
    rf.avg_time,
    'Consider applying patterns with >70% success rate for ' || rf.error_category AS suggested_improvement,
    LEAST(1.0, rf.failure_count / 10.0)::FLOAT as confidence_score,
    bp.id as related_pattern_id,
    rm.id as related_memory_id
  FROM recent_failures rf
  LEFT JOIN LATERAL (
    SELECT bp2.id, bp2.pattern_content FROM best_patterns bp2
    WHERE bp2.pattern_category = rf.error_category
    LIMIT 1
  ) bp ON TRUE
  LEFT JOIN LATERAL (
    SELECT rm2.id FROM related_memories rm2 LIMIT 1
  ) rm ON TRUE
  ORDER BY rf.failure_count DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- update_weighted_priorities: 'PENDING','RUNNING' -> lowercase
DROP FUNCTION IF EXISTS update_weighted_priorities();
CREATE FUNCTION update_weighted_priorities()
RETURNS void AS $$
  UPDATE tasks SET priority = LEAST(10, priority + 1), updated_at = now()
  WHERE status IN ('pending', 'running') AND updated_at < NOW() - INTERVAL '1 hour' AND is_stuck = false;
$$ LANGUAGE sql;

-- ============================================================
-- STEP 6: Verification
-- ============================================================
SELECT 'tasks.status after migration' AS check_point, status, COUNT(*) FROM tasks GROUP BY status;
SELECT 'projects.status after migration' AS check_point, status, COUNT(*) FROM projects GROUP BY status;
SELECT 'failure_statistics view' AS check_point, COUNT(*) FROM failure_statistics;
SELECT 'task_health_metrics view' AS check_point, COUNT(*) FROM task_health_metrics;
SELECT 'get_blocked_tasks function' AS check_point, COUNT(*) FROM get_blocked_tasks();

-- === ROLLBACK - this is a dry run ===
ROLLBACK;
