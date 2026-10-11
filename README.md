# ALMA CLOUD — Infraestructura Base de Desarrollo

Entorno de desarrollo local basado en Docker Compose para el sistema ALMA CLOUD.

## Requisitos Previos

- Docker Engine 24+ y Docker Compose v2+
- Servidor Linux con `vm.max_map_count=262144` configurado en el host.

## Gestión de Secretos y Permisos (R-16)

Los archivos ubicados en `secrets/` (`valkey_password` y `valkey_auth.conf`) pertenecen al usuario del contenedor Valkey (`uid 999`) con permisos estrictos `600`:

```bash
sudo chown -R 999:999 secrets/
sudo chmod 700 secrets/
sudo chmod 600 secrets/*
sudo ls -ln secrets/
Nota: El usuario sin privilegios del host no puede leer estos archivos directamente sin sudo. No imprima ni exponga su contenido en consola.

Verificación de Configuración
Validación de placeholders en .env (R-11):

Bash
grep -v '^[[:space:]]*#' .env | grep -q 'CAMBIAR_ESTO' && echo "ERROR: Faltan secretos" || echo "OK: Sin placeholders"
Verificación de archivos no vacíos (R-18):

Bash
test -s config/valkey.conf && echo "OK: valkey.conf no está vacío" || echo "ERROR: valkey.conf vacío"
Validación de sintaxis Compose:

Bash
docker compose config -q
