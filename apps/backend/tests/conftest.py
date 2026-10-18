"""Fixtures de test. Env defaults + mock de DB y auth."""
import os

# El guard de app/core/config.py exige POSTGRES_APP_PASSWORD para
# construir DATABASE_URL al importar app.main. Los tests no tocan la
# BD real (mock_db), así que este valor es solo para permitir el import.
os.environ.setdefault("POSTGRES_APP_USER", "alma_app")
os.environ.setdefault("POSTGRES_APP_PASSWORD", "test-only-not-used")

import pytest
from unittest.mock import AsyncMock, MagicMock
from httpx import AsyncClient, ASGITransport

from app.main import app
from app.api.deps import get_db
from app.api.v1.admin import SUPER


@pytest.fixture
def mock_db():
    db = AsyncMock()
    r = MagicMock()
    r.scalars.return_value.all.return_value = []
    r.scalar.return_value = 0
    r.scalar_one_or_none.return_value = None
    db.execute = AsyncMock(return_value=r)
    return db


@pytest.fixture
async def client(mock_db):
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[SUPER.dependency] = lambda: MagicMock()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
