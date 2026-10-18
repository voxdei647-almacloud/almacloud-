import pytest


@pytest.mark.asyncio
async def test_list_tenants_returns_array(client):
    r = await client.get("/api/v1/admin/tenants")
    assert r.status_code == 200
    assert isinstance(r.json(), list)


@pytest.mark.asyncio
async def test_list_tenants_header_total(client):
    r = await client.get("/api/v1/admin/tenants")
    assert "x-total-count" in {k.lower() for k in r.headers}


@pytest.mark.asyncio
async def test_billing_metrics_shape(client):
    r = await client.get("/api/v1/admin/billing/metrics")
    d = r.json()
    assert r.status_code == 200
    assert d["mrr"] == 0
    assert d["arr"] == 0
    assert d["mrr_history"] == []
    assert d["_mock"] is True
    assert isinstance(d["tenants_total"], int)


@pytest.mark.asyncio
async def test_health_services_shape(client):
    r = await client.get("/api/v1/admin/health/services")
    d = r.json()
    assert d["services"][0]["name"] == "PostgreSQL"
    assert d["uptime_30d"] is None
    assert d["_mock"] is True


@pytest.mark.asyncio
async def test_tenant_detail_404(client):
    r = await client.get("/api/v1/admin/tenants/00000000-0000-0000-0000-000000000000")
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_audit_returns_list(client):
    r = await client.get("/api/v1/admin/audit/recent")
    assert r.status_code == 200
    assert isinstance(r.json(), list)
