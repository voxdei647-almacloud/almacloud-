-- ALMA CLOUD - pruebas negativas de aislamiento. No deja datos (termina en ROLLBACK).
BEGIN;

INSERT INTO alma.tenants (id, slug, name) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'tenant-a', 'Tenant A'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'tenant-b', 'Tenant B');

INSERT INTO alma.sensors (id, tenant_id, hostname, profile) VALUES
  ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'host-a', 'endpoint'),
  ('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'host-b', 'network');

DO $$
DECLARE r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'alma_app') THEN
    RAISE EXCEPTION 'FAIL T10a: alma_app no existe (falta el bootstrap)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'alma_app'
             AND (rolsuper OR rolbypassrls OR rolcreaterole OR rolcreatedb)) THEN
    RAISE EXCEPTION 'FAIL T10a: alma_app tiene privilegios de más';
  END IF;
  FOR r IN SELECT c.relname, c.relrowsecurity, c.relforcerowsecurity, pg_get_userbyid(c.relowner) AS owner
           FROM pg_class c WHERE c.relnamespace = 'alma'::regnamespace AND c.relkind = 'r' LOOP
    IF NOT (r.relrowsecurity AND r.relforcerowsecurity) THEN
      RAISE EXCEPTION 'FAIL T10b: % sin RLS forzado', r.relname;
    END IF;
    IF r.owner = 'alma_app' THEN
      RAISE EXCEPTION 'FAIL T10c: alma_app es dueño de %', r.relname;
    END IF;
  END LOOP;
  RAISE NOTICE 'PASS T10: alma_app sin superusuario/BYPASSRLS, no es dueño, RLS forzado en todas las tablas';
END $$;

SET LOCAL ROLE alma_app;
SELECT set_config('app.current_tenant_id', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true) AS ctx \gset

DO $$
DECLARE n int;
BEGIN
  IF current_user <> 'alma_app' THEN RAISE EXCEPTION 'FAIL T0: la prueba no corre como alma_app'; END IF;
  RAISE NOTICE 'PASS T0: la prueba corre como alma_app';

  SELECT count(*) INTO n FROM alma.sensors;
  IF n <> 1 THEN RAISE EXCEPTION 'FAIL T1: A ve % sensores (esperado 1)', n; END IF;

  SELECT count(*) INTO n FROM alma.tenants;
  IF n <> 1 THEN RAISE EXCEPTION 'FAIL T1: A ve % tenants (esperado 1)', n; END IF;
  RAISE NOTICE 'PASS T1: A solo ve su sensor y su tenant';

  SELECT count(*) INTO n FROM alma.sensors WHERE id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1';
  IF n <> 0 THEN RAISE EXCEPTION 'FAIL T2: A lee el sensor de B'; END IF;
  RAISE NOTICE 'PASS T2: A no puede leer el sensor de B';

  UPDATE alma.sensors SET hostname = 'hack' WHERE id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION 'FAIL T3: A modificó el sensor de B'; END IF;
  RAISE NOTICE 'PASS T3: A no puede modificar el sensor de B';

  DELETE FROM alma.sensors WHERE id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION 'FAIL T4: A borró el sensor de B'; END IF;
  RAISE NOTICE 'PASS T4: A no puede borrar el sensor de B';

  BEGIN
    INSERT INTO alma.sensors (tenant_id, hostname, profile)
      VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'intruso', 'endpoint');
    RAISE EXCEPTION 'FAIL T5: A insertó un sensor en el tenant B';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS T5: A no puede insertar un sensor en B';
  END;

  BEGIN
    UPDATE alma.sensors SET tenant_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
      WHERE id = 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1';
    RAISE EXCEPTION 'FAIL T6: A movió un sensor propio al tenant B';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS T6: A no puede mover un sensor a B';
  END;

  BEGIN
    INSERT INTO alma.tenants (slug, name) VALUES ('nuevo', 'Nuevo');
    RAISE EXCEPTION 'FAIL T8: la aplicación creó un tenant';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS T8: la aplicación no puede crear tenants';
  END;

  BEGIN
    EXECUTE 'CREATE TABLE alma.intruso (i int)';
    RAISE EXCEPTION 'FAIL T9: la aplicación creó una tabla';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS T9: la aplicación no puede hacer DDL';
  END;

  PERFORM set_config('app.current_tenant_id', '', true);
  SELECT count(*) INTO n FROM alma.sensors;
  IF n <> 0 THEN RAISE EXCEPTION 'FAIL T7: sin contexto se ven % sensores', n; END IF;
  RAISE NOTICE 'PASS T7: sin contexto de tenant no se ve nada';
END $$;

ROLLBACK;

BEGIN;
SET LOCAL ROLE alma_app;
SELECT set_config('app.current_tenant_id', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true) AS ctx \gset
COMMIT;

DO $$
BEGIN
  IF NULLIF(current_setting('app.current_tenant_id', true), '') IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL T11: el contexto de tenant sobrevivió al COMMIT';
  END IF;
  RAISE NOTICE 'PASS T11: el contexto no se filtra entre transacciones';
END $$;
