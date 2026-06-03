-- Fix issues that have resolved_at set but status is NULL or empty
-- These were likely resolved via direct DB update without setting status
UPDATE issues SET status = 'resolved' WHERE resolved_at IS NOT NULL AND (status IS NULL OR status = '');
