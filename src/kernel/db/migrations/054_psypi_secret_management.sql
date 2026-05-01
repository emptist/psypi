-- Migration: 054_psypi_secret_management
-- Description: Store PSYPI_SECRET in DB config table for persistence

CREATE TABLE IF NOT EXISTS psypi_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    encrypted BOOLEAN DEFAULT false,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Function to get config value
CREATE OR REPLACE FUNCTION get_config(p_key TEXT)
RETURNS TEXT AS $$
DECLARE
    v_value TEXT;
BEGIN
    SELECT value INTO v_value FROM psypi_config WHERE key = p_key;
    RETURN v_value;
END;
$$ LANGUAGE plpgsql;

-- Function to set config value
CREATE OR REPLACE FUNCTION set_config(p_key TEXT, p_value TEXT, p_encrypt BOOLEAN DEFAULT false)
RETURNS VOID AS $$
BEGIN
    INSERT INTO psypi_config (key, value, encrypted, updated_at)
    VALUES (p_key, p_value, p_encrypt, NOW())
    ON CONFLICT (key) DO UPDATE SET
        value = EXCLUDED.value,
        encrypted = EXCLUDED.encrypted,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

GRANT SELECT, INSERT, UPDATE ON psypi_config TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_config(TEXT) TO PUBLIC;
GRANT EXECUTE ON FUNCTION set_config(TEXT, TEXT, BOOLEAN) TO PUBLIC;
