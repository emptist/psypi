-- Migration: 032_backfill_project_url
-- One-time data migration: delete old data, backfill recent data with current project_url.
-- This migration runs only once on the existing database.

-- Delete old data (> 5 days)
DELETE FROM tasks WHERE created_at < NOW() - INTERVAL '5 days';
DELETE FROM issues WHERE created_at < NOW() - INTERVAL '5 days';
DELETE FROM project_communications;

-- Backfill recent data (≤ 5 days) with current project_url
UPDATE tasks SET project_url = 'git@github.com:emptist/psypi' WHERE created_at >= NOW() - INTERVAL '5 days';
UPDATE issues SET project_url = 'git@github.com:emptist/psypi' WHERE created_at >= NOW() - INTERVAL '5 days';

-- Backfill system_reviews (all existing rows get current project_url)
UPDATE system_reviews SET project_url = 'git@github.com:emptist/psypi' WHERE project_url IS NULL;

-- Delete all old inter_reviews data (logic changed — no longer bound to tasks)
DELETE FROM inter_reviews;

-- Add project_url to inter_reviews
ALTER TABLE inter_reviews ADD COLUMN project_url text NOT NULL DEFAULT 'git@github.com:emptist/psypi';

-- Drop task_id FK and column
ALTER TABLE inter_reviews DROP CONSTRAINT IF EXISTS inter_reviews_task_id_fkey;
ALTER TABLE inter_reviews DROP COLUMN IF EXISTS task_id;

-- Remove the default (project_url should always be set explicitly from Gleam)
ALTER TABLE inter_reviews ALTER COLUMN project_url DROP DEFAULT;
