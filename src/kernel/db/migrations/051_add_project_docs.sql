-- Add project_docs table to store AGENTS.md and project context in DB
CREATE TABLE IF NOT EXISTS project_docs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  doc_type TEXT NOT NULL UNIQUE, -- 'agents_md', 'project_context', 'readme'
  content TEXT NOT NULL,
  project_name TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS idx_project_docs_type ON project_docs(doc_type);

-- Comment
COMMENT ON TABLE project_docs IS 'Stores project documentation (AGENTS.md, README.md, project context) for easy access by AI reviewers';
COMMENT ON COLUMN project_docs.doc_type IS 'Document type: agents_md, project_context, readme, etc.';
COMMENT ON COLUMN project_docs.content IS 'Full document content';
COMMENT ON COLUMN project_docs.project_name IS 'Name of the project this doc belongs to';
