-- 0008: Permitir a super_admin insertar/leer en audit_logs
-- (la migración 0006 no lo incluyó)

DROP POLICY IF EXISTS audit_logs_tenant_isolation ON alma.audit_logs;

CREATE POLICY audit_logs_isolation ON alma.audit_logs
    FOR ALL TO alma_app
    USING (
        tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid
        OR current_setting('app.current_role', true) = 'super_admin'
    )
    WITH CHECK (
        tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid
        OR current_setting('app.current_role', true) = 'super_admin'
    );

-- Hacer lo mismo para sensors y sensor_credentials (por si acaso)
DROP POLICY IF EXISTS tenant_isolation ON alma.sensors;
CREATE POLICY sensors_isolation ON alma.sensors
    FOR ALL TO alma_app
    USING (
        tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid
        OR current_setting('app.current_role', true) = 'super_admin'
    );

DROP POLICY IF EXISTS sensor_credentials_isolation ON alma.sensor_credentials;
CREATE POLICY sensor_credentials_isolation ON alma.sensor_credentials
    FOR ALL TO alma_app
    USING (
        tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid
        OR current_setting('app.current_role', true) = 'super_admin'
    );
