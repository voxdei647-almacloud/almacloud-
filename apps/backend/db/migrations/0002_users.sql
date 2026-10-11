CREATE TABLE IF NOT EXISTS alma.users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES alma.tenants(id) ON DELETE CASCADE,
  email         varchar(255) NOT NULL,
  password_hash varchar(255) NOT NULL,
  role          varchar(32) NOT NULL DEFAULT 'analyst' CHECK (role IN ('admin', 'analyst', 'sensor', 'system')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT users_tenant_email_key UNIQUE (tenant_id, email)
);

ALTER TABLE alma.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE alma.users FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_tenant_isolation ON alma.users;
CREATE POLICY users_tenant_isolation ON alma.users
  USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
  WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid);

GRANT ALL ON alma.users TO alma_app;
