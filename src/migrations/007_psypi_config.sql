CREATE TABLE IF NOT EXISTS psypi_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO psypi_config (key, value) VALUES
  ('monitor_debounce_ms', '180000')
ON CONFLICT (key) DO NOTHING;
