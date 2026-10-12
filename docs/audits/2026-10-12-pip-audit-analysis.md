# Análisis del Reporte pip-audit

**Fecha:** 2026-10-12
**Reporte crudo:** `2026-10-12-pip-audit-report.txt`
**Veredicto global:** 15 hallazgos en 3 paquetes, 0 explotables en runtime. Deuda técnica menor.

## Resumen por paquete

| Paquete | Versión | CVEs | Acción |
|---|---|---|---|
| `pip` | 25.1.1 | 11 (PYSEC-2026-1795/1796/196/2875/2876/3721) | Actualizar pip al recrear el venv. No explotable en runtime |
| `ecdsa` | 0.19.2 | 1 (PYSEC-2026-1325) | Sin fix upstream. No usado por ALMA (usa RS256, no ES256) |
| `python-jose` | 3.5.0 | 1 (CVE-2026-85394) | Mitigado por diseño. Migrar a PyJWT en Incremento 0008 |

## Detalle

### pip 25.1.1
Vulnerabilidades limitadas al proceso de instalación/extracción de paquetes. No afectan al entorno de ejecución en producción.
Mitigación: Mantener fuentes de paquetes confiables y actualizar pip a >=26.2 al regenerar el venv.

### ecdsa 0.19.2
Attack de canal lateral (Minerva timing attack). El proyecto upstream no contempla parches para side-channel. ALMA CLOUD utiliza **RS256** (`security.py`), no ECDSA. Librería retenida únicamente como dependencia transitiva.

### python-jose 3.5.0 (CVE-2026-85394)
Confusión de algoritmo HS256/RS256. Mitigado explícitamente en `apps/backend/app/core/security.py` fijando `algorithms=[JWT_ALGORITHM]` (RS256 estricto).
Acción planificada (Incremento 0008): Reemplazar `python-jose` por `PyJWT`.
