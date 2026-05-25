ALTER TABLE agent_jobs
  ADD CONSTRAINT uq_agent_jobs_soul_job_priority_category
  UNIQUE (soul_id, job, priority, category);
