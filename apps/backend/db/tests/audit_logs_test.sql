-- ALMA CLOUD - Pruebas de auditoría e inmutabilidad
BEGIN;

INSERT INTO alma.tenants (id, slug, name) VALUES
  ('22222222-2222-2222-2222-222222222222', 'tenant-audit', 'Tenant Audit');

SET LOCAL ROLE alma_app;

DO $$
DECLARE
  v_log_id uuid;
  v_count int;
BEGIN
  -- Establecer contexto del tenant
  PERFORM set_config('app.current_tenant_id', '22222222-2222-2222-2222-222222222222', true);

  -- Test A1: Inserción de evento de auditoría
  INSERT INTO alma.audit_logs (tenant_id, actor_type, actor_id, action, resource, details)
  VALUES ('22222222-2222-2222-2222-222222222222', 'system', 'admin_ui', 'sensor.enrolled', 'sensor:srv-01', '{"ip": "192.168.1.1"}'::jsonb)
  RETURNING id INTO v_log_id;

  IF v_log_id IS NULL THEN
    RAISE EXCEPTION 'FAIL A1: No se pudo insertar el registro de auditoría';
  END IF;
  RAISE NOTICE 'PASS A1: Inserción de auditoría exitosa (ID: %)', v_log_id;

  -- Test A2: Lectura de auditoría filtrada por tenant
  SELECT count(*) INTO v_count FROM alma.audit_logs;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'FAIL A2: Se esperaban 1 registro, se encontraron %', v_count;
  END IF;
  RAISE NOTICE 'PASS A2: Lectura de auditoría aislada por tenant';

  -- Test A3: Intento de UPDATE debe ser rechazado por falta de permisos de RDBMS
  BEGIN
    UPDATE alma.audit_logs SET action = 'tampered' WHERE id = v_log_id;
    RAISE EXCEPTION 'FAIL A3: Se permitió UPDATE en registros de auditoría';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS A3: Inmutabilidad confirmada (UPDATE denegado a alma_app)';
  END;

  -- Test A4: Intento de DELETE debe ser rechazado por falta de permisos de RDBMS
  BEGIN
    DELETE FROM alma.audit_logs WHERE id = v_log_id;
    RAISE EXCEPTION 'FAIL A4: Se permitió DELETE en registros de auditoría';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS A4: Inmutabilidad confirmada (DELETE denegado a alma_app)';
  END;

END $$;

ROLLBACK;
