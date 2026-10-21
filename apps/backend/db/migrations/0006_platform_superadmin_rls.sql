-- 0006: Ajuste de RLS para permitir acceso global a super_admin
-- Idempotente: elimina la política si ya existe antes de crearla.

-- Tenants
DROP POLICY IF EXISTS tenants_self ON alma.tenants;
DROP POLICY IF EXISTS tenants_isolation ON alma.tenants;

CREATE POLICY tenants_isolation ON alma.tenants
    FOR ALL TO alma_app
    USING (
        id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid
        OR current_setting('app.current_role', true) = 'super_admin'
    );

-- Users
DROP POLICY IF EXISTS users_tenant_isolation ON alma.users;
DROP POLICY IF EXISTS users_isolation ON alma.users;

CREATE POLICY users_isolation ON alma.users
    FOR ALL TO alma_app
    USING (
        tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid
        OR current_setting('app.current_role', true) = 'super_admin'
    );
