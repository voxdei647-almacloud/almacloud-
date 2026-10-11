import redis.asyncio as redis
from app.core.config import settings

valkey_client: redis.Redis | None = None


async def init_valkey() -> None:
    global valkey_client
    valkey_client = redis.Redis(
        host=settings.VALKEY_HOST,
        port=settings.VALKEY_PORT,
        password=settings.VALKEY_AUTH_PASSWORD,
        decode_responses=True,
    )


async def close_valkey() -> None:
    global valkey_client
    if valkey_client:
        await valkey_client.aclose()


async def get_valkey_client() -> redis.Redis:
    if valkey_client is None:
        await init_valkey()
    return valkey_client
