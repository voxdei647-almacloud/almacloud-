-- 0005: añade plan y status a alma.tenants para el dashboard admin.
ALTER TABLE alma.tenants
    ADD COLUMN IF NOT EXISTS plan   VARCHAR(16) NOT NULL DEFAULT 'basic'
        CHECK (plan IN ('basic', 'pro', 'enterprise')),
    ADD COLUMN IF NOT EXISTS status VARCHAR(16) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'past_due', 'suspended'));

COMMENT ON COLUMN alma.tenants.plan   IS 'Plan comercial. MRR se calcula en billing_snapshots (no aquí).';
COMMENT ON COLUMN alma.tenants.status IS 'active | past_due | suspended.';
