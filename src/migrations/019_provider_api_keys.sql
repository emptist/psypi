CREATE TABLE IF NOT EXISTS provider_api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider TEXT NOT NULL UNIQUE,
    model VARCHAR(255) DEFAULT '',
    status TEXT NOT NULL DEFAULT 'not_used' CHECK (status IN ('not_used', 'in_use', 'error')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_provider_api_keys_status ON provider_api_keys(status);
