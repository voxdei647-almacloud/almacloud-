# Registro de Deuda Técnica: Contexto RLS por Transacción (SET LOCAL)

**Fecha:** 2026-10-12
**Componente:** `apps/backend/app/core/database.py` y endpoints API
**Impacto:** Medio (Riesgo potencial de reutilización del setting en pool)

## Problema

`get_tenant_db` usa `set_config('app.current_tenant_id', :tenant_id, false)`
(ámbito de sesión). Cambiar a `is_local=true` (SET LOCAL) hace fallar
endpoints como `create_sensor` que ejecutan `await db.commit()` intermedio
antes de insertar en `alma.audit_logs`: la transacción cierra, el SET LOCAL
muere, y el INSERT posterior viola RLS.

## Estrategia de Solución (Incremento 0007)

1. Auditar invocaciones a `commit()` en `sensors.py`, `auth.py`, `telemetry.py`.
2. Refactorizar cada endpoint con `commit + query protegida` a una de:
   - `async with session.begin()` envolviendo todo, o
   - re-aplicar `set_config` tras cada commit.
3. Migrar `get_tenant_db` a `set_config(..., true)` + `rollback()` en `finally`.
4. Añadir prueba de fuga entre peticiones concurrentes (pool de 1 conexión,
   dos tenants distintos).

## Referencia

Detectado durante el Incremento 0004 (aplicación de `SET LOCAL`).
Revierte el parche de `database.py` pero mantiene el de `config.py`.
