-- ALMA CLOUD - migración 0001: tenants y sensors con RLS. Se ejecuta UNA vez.
BEGIN;
SET LOCAL ROLE alma_migrator;

CREATE TABLE alma.tenants (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug       text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$'),
  name       text NOT NULL CHECK (length(name) BETWEEN 1 AND 200),
  status     text NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE alma.sensors (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL REFERENCES alma.tenants(id),
  hostname         text NOT NULL CHECK (length(hostname) BETWEEN 1 AND 253),
  profile          text NOT NULL CHECK (profile IN ('endpoint','network')),
  lifecycle_status text NOT NULL DEFAULT 'active' CHECK (lifecycle_status IN ('active','revoked')),
  last_seen_at     timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id)
);

CREATE INDEX sensors_tenant_idx ON alma.sensors (tenant_id);

ALTER TABLE alma.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE alma.tenants FORCE  ROW LEVEL SECURITY;
ALTER TABLE alma.sensors ENABLE ROW LEVEL SECURITY;
ALTER TABLE alma.sensors FORCE  ROW LEVEL SECURITY;

CREATE POLICY tenants_self ON alma.tenants FOR SELECT TO alma_app
  USING (id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid);

CREATE POLICY tenant_isolation ON alma.sensors FOR ALL TO alma_app
  USING      (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
  WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid);

GRANT SELECT ON alma.tenants TO alma_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON alma.sensors TO alma_app;

COMMIT;
