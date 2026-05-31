-- Migration 031: Remove code_versions backups for deleted a_orchestrator.gleam
--
-- a_orchestrator.gleam was removed (its logic was inlined into
-- hook_on_agent_end.gleam). The auto-backup records are renamed
-- to DELETED/ prefix so psypi-doc-list won't find them under the
-- original file_path.

UPDATE code_versions SET file_path = 'DELETED/src/a_orchestrator.gleam'
  WHERE file_path = 'src/a_orchestrator.gleam';
