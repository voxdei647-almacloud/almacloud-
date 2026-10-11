-- ALMA CLOUD - Pruebas de credenciales y enrolamiento atómico
BEGIN;

INSERT INTO alma.tenants (id, slug, name) VALUES
  ('11111111-1111-1111-1111-111111111111', 'tenant-enroll', 'Tenant Enrolment');

INSERT INTO alma.enrollment_tokens (id, tenant_id, token_hash, created_by, created_at, expires_at) VALUES
  ('e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1', '11111111-1111-1111-1111-111111111111',
   '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff', 'admin', now(), now() + interval '1 hour'),
  ('e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2', '11111111-1111-1111-1111-111111111111',
   '222233334444555566667777888899990000aaaabbbbccccddddeeeeffff1111', 'admin', now() - interval '2 hours', now() - interval '1 hour');

SET LOCAL ROLE alma_app;

DO $$
DECLARE
  v_res jsonb;
  v_cred_count int;
BEGIN
  -- Test E1: Enrolamiento exitoso con token válido
  v_res := alma.enroll_sensor(
    '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff',
    'srv-enrolled-01',
    'endpoint',
    'pfx_ctrl_01',
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
    'pfx_tele_01',
    'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5'
  );
  RAISE NOTICE 'PASS E1: Enrolamiento atómico completado para sensor %', v_res->>'sensor_id';

  -- Test E2: Reutilización de token consumido debe fallar
  BEGIN
    PERFORM alma.enroll_sensor(
      '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff',
      'srv-enrolled-02', 'endpoint', 'pfx_ctrl_02', 'hash2_ctrl', 'pfx_tele_02', 'hash2_tele'
    );
    RAISE EXCEPTION 'FAIL E2: Se permitió reutilizar un token consumido';
  EXCEPTION WHEN invalid_authorization_specification THEN
    RAISE NOTICE 'PASS E2: Rechazado re-uso de token consumido';
  END;

  -- Test E3: Token expirado debe fallar
  BEGIN
    PERFORM alma.enroll_sensor(
      '222233334444555566667777888899990000aaaabbbbccccddddeeeeffff1111',
      'srv-enrolled-03', 'endpoint', 'pfx_ctrl_03', 'hash3_ctrl', 'pfx_tele_03', 'hash3_tele'
    );
    RAISE EXCEPTION 'FAIL E3: Se permitió enrolar con token expirado';
  EXCEPTION WHEN invalid_authorization_specification THEN
    RAISE NOTICE 'PASS E3: Rechazado token expirado';
  END;

  -- Test E4: Verificar creación de credenciales independientes (Control y Telemetría)
  PERFORM set_config('app.current_tenant_id', '11111111-1111-1111-1111-111111111111', true);
  SELECT count(*) INTO v_cred_count FROM alma.sensor_credentials WHERE sensor_id = (v_res->>'sensor_id')::uuid;
  IF v_cred_count <> 2 THEN
    RAISE EXCEPTION 'FAIL E4: Se esperaban 2 credenciales, encontradas %', v_cred_count;
  END IF;
  RAISE NOTICE 'PASS E4: Credenciales de control y telemetría generadas independientemente';

END $$;

ROLLBACK;
