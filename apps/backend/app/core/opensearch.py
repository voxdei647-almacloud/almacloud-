from opensearchpy import AsyncOpenSearch
from app.core.config import settings

opensearch_client: AsyncOpenSearch | None = None


async def init_opensearch() -> None:
    global opensearch_client
    opensearch_client = AsyncOpenSearch(
        hosts=[{"host": settings.OPENSEARCH_HOST, "port": settings.OPENSEARCH_PORT}],
        http_auth=(settings.OPENSEARCH_USER, settings.OPENSEARCH_AUTH_PASSWORD),
        use_ssl=False,
        verify_certs=False,
        ssl_show_warn=False,
    )


async def close_opensearch() -> None:
    global opensearch_client
    if opensearch_client:
        await opensearch_client.close()


async def get_opensearch_client() -> AsyncOpenSearch:
    if opensearch_client is None:
        await init_opensearch()
    return opensearch_client
