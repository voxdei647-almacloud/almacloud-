
### 2026-10-18 — Integración E2E y Facturación Real (Fases B y C)
- **Autenticación Cross-VM:** El SIEM (VM 105) consume exitosamente los endpoints de ALMA (VM 107) usando `ALMA_SERVICE_TOKEN`.
- **Login Arreglado:** Se resolvió el bug de RLS en `audit_logs` durante el login. El JWT ahora se emite con el `tenant_id` real.
- **Facturación Real:** Implementada tabla `billing_snapshots` (Migración 0007) y lógica de cálculo de MRR en `/admin/billing/metrics` (devuelve `_mock: false`).
- **Validación Frontend:** Los logs de Flask confirman que el dashboard de Armando consume los 4 endpoints de admin correctamente (HTTP 200).

### 2026-10-18 — Endpoints de Escritura (Admin CRUD)
- Añadidos endpoints POST, PATCH y DELETE a `admin.py`.
- Otorgados permisos de UPDATE/DELETE a `alma_app` en PostgreSQL.
- Probado exitosamente: creación de usuario, suspensión de tenant y revocación de usuario.
