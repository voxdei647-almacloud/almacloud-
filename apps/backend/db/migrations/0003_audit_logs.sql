-- ALMA CLOUD - migración 0003: registros de auditoría inmutables por tenant
BEGIN;
SET LOCAL ROLE alma_migrator;

CREATE TABLE alma.audit_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES alma.tenants(id) ON DELETE CASCADE,
  actor_type  text NOT NULL CHECK (actor_type IN ('user', 'sensor', 'system')),
  actor_id    text NOT NULL,
  action      text NOT NULL CHECK (length(action) BETWEEN 3 AND 100),
  resource    text NOT NULL CHECK (length(resource) BETWEEN 3 AND 100),
  details     jsonb NOT NULL DEFAULT '{}'::jsonb,
  ip_address  inet,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX audit_logs_tenant_created_idx ON alma.audit_logs (tenant_id, created_at DESC);
CREATE INDEX audit_logs_action_idx ON alma.audit_logs (tenant_id, action);

ALTER TABLE alma.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE alma.audit_logs FORCE  ROW LEVEL SECURITY;

-- Política RLS: Lectura e inserción únicamente bajo el contexto del tenant activo
CREATE POLICY audit_logs_tenant_isolation ON alma.audit_logs FOR ALL TO PUBLIC
  USING      (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
  WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid);

-- Otorgar solo SELECT e INSERT a la aplicación (sin UPDATE ni DELETE)
GRANT SELECT, INSERT ON alma.audit_logs TO alma_app;

COMMIT;
