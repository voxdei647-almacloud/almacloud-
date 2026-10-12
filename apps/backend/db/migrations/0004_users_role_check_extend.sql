-- Migración 0004: Ampliar restricción de roles en la tabla alma.users

BEGIN;

ALTER TABLE alma.users
  DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE alma.users
  ADD CONSTRAINT users_role_check
  CHECK (role IN ('super_admin', 'tenant_admin', 'admin', 'analyst', 'sensor', 'system'));

COMMIT;
