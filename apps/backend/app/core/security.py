import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, Optional
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from jose import jwt, JWTError

JWT_ALGORITHM = "RS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60
JWT_ISSUER = os.getenv("JWT_ISSUER", "alma-cloud")
JWT_AUDIENCE = os.getenv("JWT_AUDIENCE", "alma-api")

BASE_DIR = Path(__file__).resolve().parents[4]
JWT_PRIVATE_KEY_PATH = os.getenv("JWT_PRIVATE_KEY_PATH", str(BASE_DIR / "secrets" / "jwt_private.pem"))
JWT_PUBLIC_KEY_PATH = os.getenv("JWT_PUBLIC_KEY_PATH", str(BASE_DIR / "secrets" / "jwt_public.pem"))

ph = PasswordHasher()


def _load_key(key_path_str: str) -> str:
    path = Path(key_path_str)
    if not path.is_absolute():
        path = BASE_DIR / key_path_str
    if not path.exists():
        raise FileNotFoundError(f"Llave JWT no encontrada en: {path}")
    return path.read_text().strip()


def get_private_key() -> str:
    return _load_key(JWT_PRIVATE_KEY_PATH)


def get_public_key() -> str:
    return _load_key(JWT_PUBLIC_KEY_PATH)


def hash_password(password: str) -> str:
    return ph.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return ph.verify(hashed_password, plain_password)
    except VerifyMismatchError:
        return False


def create_access_token(
    subject: str,
    tenant_id: str,
    role: Optional[str] = None,
    expires_delta: Optional[timedelta] = None
) -> str:
    now = datetime.now(timezone.utc)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode: Dict[str, Any] = {
        "sub": subject,
        "tenant_id": tenant_id,
        "iss": JWT_ISSUER,
        "aud": JWT_AUDIENCE,
        "exp": expire,
        "iat": now
    }
    if role:
        to_encode["role"] = role

    private_key = get_private_key()
    return jwt.encode(to_encode, private_key, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> Optional[Dict[str, Any]]:
    try:
        public_key = get_public_key()
        payload = jwt.decode(
            token,
            public_key,
            algorithms=[JWT_ALGORITHM],
            issuer=JWT_ISSUER,
            audience=JWT_AUDIENCE,
            options={"verify_exp": True, "verify_iss": True, "verify_aud": True}
        )
        return payload
    except JWTError:
        return None
