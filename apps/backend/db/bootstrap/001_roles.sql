-- ALMA CLOUD - bootstrap de roles (ejecutar como superusuario). Idempotente. Sin contraseñas.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'alma_migrator') THEN
    CREATE ROLE alma_migrator NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'alma_app') THEN
    CREATE ROLE alma_app NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
  END IF;
END$$;

CREATE SCHEMA IF NOT EXISTS alma AUTHORIZATION alma_migrator;
REVOKE ALL ON SCHEMA alma FROM PUBLIC;
GRANT USAGE ON SCHEMA alma TO alma_app;
