-- 0007: Tabla de facturación e ingresos
CREATE TABLE IF NOT EXISTS alma.billing_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES alma.tenants(id) ON DELETE CASCADE,
    amount_usd NUMERIC(10, 2) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('paid', 'pending', 'failed')),
    snapshot_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Aplicar RLS
ALTER TABLE alma.billing_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE alma.billing_snapshots FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS billing_isolation ON alma.billing_snapshots;
CREATE POLICY billing_isolation ON alma.billing_snapshots
    FOR ALL TO alma_app
    USING (
        tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid
        OR current_setting('app.current_role', true) = 'super_admin'
    );

-- Dar permisos
GRANT SELECT, INSERT, UPDATE, DELETE ON alma.billing_snapshots TO alma_app;
