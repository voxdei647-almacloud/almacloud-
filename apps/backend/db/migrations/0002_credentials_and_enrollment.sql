-- ALMA CLOUD - migración 0002: credenciales de sensores y enrolamiento atómico
BEGIN;
SET LOCAL ROLE alma_migrator;

-- Tabla de credenciales de sensores (Canales de control y telemetría separados - Decisión A2)
CREATE TABLE alma.sensor_credentials (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL,
  sensor_id    uuid NOT NULL,
  channel      text NOT NULL CHECK (channel IN ('control', 'telemetry')),
  key_prefix   text NOT NULL UNIQUE CHECK (length(key_prefix) >= 8),
  key_hash     text NOT NULL CHECK (length(key_hash) = 64),
  status       text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  expires_at   timestamptz,
  revoked_at   timestamptz,
  FOREIGN KEY (tenant_id, sensor_id) REFERENCES alma.sensors(tenant_id, id) ON DELETE CASCADE
);

CREATE INDEX sensor_credentials_lookup_idx ON alma.sensor_credentials (key_prefix) WHERE status = 'active';
CREATE INDEX sensor_credentials_sensor_idx ON alma.sensor_credentials (tenant_id, sensor_id);

ALTER TABLE alma.sensor_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE alma.sensor_credentials FORCE  ROW LEVEL SECURITY;

CREATE POLICY sensor_credentials_isolation ON alma.sensor_credentials FOR ALL TO PUBLIC
  USING      (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
  WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON alma.sensor_credentials TO alma_app;

-- Tabla de tokens de enrolamiento
CREATE TABLE alma.enrollment_tokens (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL REFERENCES alma.tenants(id) ON DELETE CASCADE,
  token_hash         text NOT NULL UNIQUE CHECK (length(token_hash) = 64),
  created_by         text NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  expires_at         timestamptz NOT NULL CHECK (expires_at > created_at),
  consumed_at        timestamptz,
  consumed_sensor_id uuid
);

CREATE INDEX enrollment_tokens_tenant_idx ON alma.enrollment_tokens (tenant_id);

ALTER TABLE alma.enrollment_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE alma.enrollment_tokens FORCE  ROW LEVEL SECURITY;

CREATE POLICY enrollment_tokens_tenant_isolation ON alma.enrollment_tokens FOR ALL TO PUBLIC
  USING      (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
  WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid);

CREATE POLICY enrollment_tokens_unconsumed_access ON alma.enrollment_tokens FOR ALL TO PUBLIC
  USING      (consumed_at IS NULL AND expires_at > now());

GRANT SELECT, UPDATE ON alma.enrollment_tokens TO alma_app;

-- Función SECURITY DEFINER para enrolamiento atómico
CREATE OR REPLACE FUNCTION alma.enroll_sensor(
  p_token_hash text,
  p_hostname text,
  p_profile text,
  p_control_prefix text,
  p_control_hash text,
  p_telemetry_prefix text,
  p_telemetry_hash text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = alma, pg_temp
AS $$
DECLARE
  v_token record;
  v_sensor_id uuid;
BEGIN
  -- 1. Validar y obtener token atómicamente
  SELECT id, tenant_id INTO v_token
  FROM alma.enrollment_tokens
  WHERE token_hash = p_token_hash
    AND consumed_at IS NULL
    AND expires_at > now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'INVALID_OR_EXPIRED_TOKEN' USING ERRCODE = '28000';
  END IF;

  -- 2. Establecer el contexto del tenant recuperado para la transacción local
  PERFORM set_config('app.current_tenant_id', v_token.tenant_id::text, true);

  -- 3. Crear el sensor
  INSERT INTO alma.sensors (tenant_id, hostname, profile)
  VALUES (v_token.tenant_id, p_hostname, p_profile)
  RETURNING id INTO v_sensor_id;

  -- 4. Crear credencial de control
  INSERT INTO alma.sensor_credentials (tenant_id, sensor_id, channel, key_prefix, key_hash)
  VALUES (v_token.tenant_id, v_sensor_id, 'control', p_control_prefix, p_control_hash);

  -- 5. Crear credencial de telemetría
  INSERT INTO alma.sensor_credentials (tenant_id, sensor_id, channel, key_prefix, key_hash)
  VALUES (v_token.tenant_id, v_sensor_id, 'telemetry', p_telemetry_prefix, p_telemetry_hash);

  -- 6. Marcar token como consumido
  UPDATE alma.enrollment_tokens
  SET consumed_at = now(),
      consumed_sensor_id = v_sensor_id
  WHERE id = v_token.id;

  RETURN jsonb_build_object(
    'sensor_id', v_sensor_id,
    'tenant_id', v_token.tenant_id
  );
END;
$$;

REVOKE ALL ON FUNCTION alma.enroll_sensor FROM PUBLIC;
GRANT EXECUTE ON FUNCTION alma.enroll_sensor TO alma_app;

COMMIT;
