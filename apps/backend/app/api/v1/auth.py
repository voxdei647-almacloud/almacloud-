from sqlalchemy.exc import IntegrityError
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_db, get_current_user, require_roles
from app.core.security import hash_password, verify_password, create_access_token
from app.models.domain import User, AuditLog
from app.schemas.domain import UserCreate, UserRead, LoginRequest, TokenRead

router = APIRouter(prefix="/auth", tags=["Auth"])


ALLOWED_ROLES_FOR_TENANT_ADMIN = {"admin", "analyst", "sensor"}


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
async def register_user(
    user_in: UserCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("super_admin", "tenant_admin")),
):
    # Jerarquía: tenant_admin no puede crear roles elevados
    if current_user.role == "tenant_admin" and user_in.role not in ALLOWED_ROLES_FOR_TENANT_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                f"Un tenant_admin no puede crear el rol '{user_in.role}'. "
                f"Roles permitidos: {sorted(ALLOWED_ROLES_FOR_TENANT_ADMIN)}"
            ),
        )

    # El tenant destino SIEMPRE sale de la credencial
    tenant_uuid = current_user.tenant_id

    existing = await db.execute(
        select(User).where(User.tenant_id == tenant_uuid, User.email == user_in.email)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El correo electrónico ya se encuentra registrado en este tenant."
        )

    user = User(
        tenant_id=tenant_uuid,
        email=user_in.email,
        password_hash=hash_password(user_in.password),
        role=user_in.role
    )
    try:
        db.add(user)
        await db.flush()

        audit_entry = AuditLog(
            tenant_id=tenant_uuid,
            actor_type="user",
            actor_id=str(current_user.id),
            action="user.register",
            resource=f"user:{user.id}",
            details={
                "email": user.email,
                "role": user.role,
                "created_by": str(current_user.id),
            },
        )
        db.add(audit_entry)

        await db.commit()
        await db.refresh(user)
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Error de registro: el usuario ya existe o los datos no cumplen con las restricciones del sistema."
        )

    return user


@router.post("/login", response_model=TokenRead)
async def login(
    login_in: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    # Buscamos al usuario por email
    user_res = await db.execute(select(User).where(User.email == login_in.email))
    user = user_res.scalar_one_or_none()

    if not user or not verify_password(login_in.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales inválidas."
        )

    # Usamos el tenant_id REAL del usuario
    real_tenant_id = str(user.tenant_id)
    
    # IMPORTANTE: Actualizar el contexto de RLS al tenant real del usuario
    await db.execute(
        text("SELECT set_config('app.current_tenant_id', :t, true)"),
        {"t": real_tenant_id}
    )
    await db.execute(
        text("SELECT set_config('app.current_role', :r, true)"),
        {"r": user.role}
    )

    token = create_access_token(subject=str(user.id), tenant_id=real_tenant_id)

    audit_entry = AuditLog(
        tenant_id=user.tenant_id,  # <-- REAL tenant_id
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
        tenant_id=user.tenant_id
    )


@router.get("/me", response_model=UserRead)
async def get_me(current_user: User = Depends(get_current_user)):
    return current_user
