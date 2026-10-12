#!/usr/bin/env python3
"""
Bootstrap del primer super_admin de ALMA CLOUD.
"""
import asyncio
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "apps" / "backend"))

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine
from app.core.security import hash_password


def _require(name: str) -> str:
    val = os.getenv(name)
    if not val or val.startswith("CAMBIAR_ESTO"):
        print(f"[!] ERROR: {name} no está definido o sigue siendo placeholder.")
        sys.exit(1)
    return val


async def bootstrap() -> None:
    email = _require("BOOTSTRAP_ADMIN_EMAIL")
    password = _require("BOOTSTRAP_ADMIN_PASSWORD")
    tenant_id = _require("BOOTSTRAP_TENANT_ID")
    tenant_name = os.getenv("BOOTSTRAP_TENANT_NAME", "Plataforma ALMA System")
    tenant_slug = os.getenv("BOOTSTRAP_TENANT_SLUG", "alma-platform")

    pg_user = _require("POSTGRES_USER")
    pg_pass = os.getenv("POSTGRES_PASSWORD")
    if not pg_pass:
        print("[!] ERROR: POSTGRES_PASSWORD no está definido en el entorno.")
        sys.exit(1)
    pg_host = os.getenv("POSTGRES_HOST", "127.0.0.1")
    pg_port = os.getenv("POSTGRES_PORT", "5432")
    pg_db = os.getenv("POSTGRES_DB", "alma_cloud")
    url = f"postgresql+asyncpg://{pg_user}:{pg_pass}@{pg_host}:{pg_port}/{pg_db}"

    engine = create_async_engine(url, echo=False)
    hashed_pw = hash_password(password)

    async with engine.begin() as conn:
        # 1. Tenant system (idempotente por PK)
        await conn.execute(
            text("""
                INSERT INTO alma.tenants (id, slug, name, status, created_at, updated_at)
                VALUES (:id, :slug, :name, 'active', NOW(), NOW())
                ON CONFLICT (id) DO UPDATE
                SET name = EXCLUDED.name,
                    slug = EXCLUDED.slug,
                    status = EXCLUDED.status,
                    updated_at = NOW()
            """),
            {"id": tenant_id, "slug": tenant_slug, "name": tenant_name},
        )
        print(f"[+] Tenant '{tenant_slug}' ({tenant_id}) asegurado.")

        # 2. Super admin (idempotente por UNIQUE (tenant_id, email))
        res = await conn.execute(
            text("""
                INSERT INTO alma.users (tenant_id, email, password_hash, role, created_at)
                VALUES (:tenant_id, :email, :hpw, 'super_admin', NOW())
                ON CONFLICT (tenant_id, email) DO UPDATE
                SET role = 'super_admin',
                    password_hash = EXCLUDED.password_hash
                RETURNING id, email, role, tenant_id
            """),
            {"tenant_id": tenant_id, "email": email, "hpw": hashed_pw},
        )
        row = res.mappings().one()
        print(f"[+] Super admin '{row['email']}' (role={row['role']}, id={row['id']}) listo en tenant {row['tenant_id']}.")

    await engine.dispose()
    print("[+] Bootstrap completado.")


if __name__ == "__main__":
    asyncio.run(bootstrap())
