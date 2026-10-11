from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_db
from app.core.security import hash_password, verify_password, create_access_token
from app.models.domain import User, AuditLog
from app.schemas.domain import UserCreate, UserRead, LoginRequest, TokenRead

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
async def register_user(
    user_in: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar()
    if not tenant_id_str:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contexto de tenant no configurado."
        )

    tenant_uuid = UUID(tenant_id_str)

    # Validar unicidad del correo por tenant
    existing = await db.execute(select(User).where(User.email == user_in.email))
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El correo electrónico ya se encuentra registrado."
        )

    user = User(
        tenant_id=tenant_uuid,
        email=user_in.email,
        password_hash=hash_password(user_in.password),
        role=user_in.role
    )
    db.add(user)
    await db.flush()

    audit_entry = AuditLog(
        tenant_id=tenant_uuid,
        actor_type="system",
        actor_id="auth_service",
        action="user.register",
        resource=f"user:{user.id}",
        details={"email": user.email, "role": user.role}
    )
    db.add(audit_entry)

    await db.commit()
    await db.refresh(user)
    return user


@router.post("/login", response_model=TokenRead)
async def login(
    login_in: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar()
    tenant_uuid = UUID(tenant_id_str)

    user_res = await db.execute(select(User).where(User.email == login_in.email))
    user = user_res.scalar_one_or_none()

    if not user or not verify_password(login_in.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales inválidas."
        )

    token = create_access_token(subject=str(user.id), tenant_id=tenant_id_str)

    audit_entry = AuditLog(
        tenant_id=tenant_uuid,
        actor_type="user",
        actor_id=str(user.id),
        action="user.login",
        resource=f"user:{user.id}",
        details={"email": user.email}
    )
    db.add(audit_entry)
    await db.commit()

    return TokenRead(
        access_token=token,
        token_type="bearer",
        tenant_id=tenant_uuid
    )
