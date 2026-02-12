"""
Tests for the CodeQuest backend API.
"""

import pytest
from httpx import AsyncClient, ASGITransport

# Ensure the backend package is importable
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from main import app


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


#  Health Check 

@pytest.mark.anyio
async def test_health(client):
    resp = await client.get("/")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert data["game"] == "CodeQuest"


#  Challenge Endpoints 

@pytest.mark.anyio
async def test_list_challenges(client):
    resp = await client.get("/challenges")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    # Each challenge should have required fields
    first = data[0]
    assert "id" in first
    assert "title" in first
    assert "test_cases" in first


@pytest.mark.anyio
async def test_get_challenge_by_id(client):
    resp = await client.get("/challenge/vars_01")
    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == "vars_01"
    assert data["area"] == "variables"


@pytest.mark.anyio
async def test_get_challenge_not_found(client):
    resp = await client.get("/challenge/nonexistent_99")
    assert resp.status_code == 404


#  Submit Endpoint 

@pytest.mark.anyio
async def test_submit_correct_code(client):
    """Submit a correct solution to vars_01 and expect full pass."""
    code = '#include <iostream>\nusing namespace std;\nint main() { cout << 42; return 0; }'
    resp = await client.post("/submit", json={
        "challenge_id": "vars_01",
        "code": code,
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["compiled"] is True
    assert data["success"] is True
    assert data["passed_count"] == data["total_count"]
    assert data["damage"] > 0
    assert data["xp_earned"] > 0


@pytest.mark.anyio
async def test_submit_wrong_output(client):
    """Submit code that compiles but produces wrong output."""
    code = '#include <iostream>\nusing namespace std;\nint main() { cout << 99; return 0; }'
    resp = await client.post("/submit", json={
        "challenge_id": "vars_01",
        "code": code,
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["compiled"] is True
    assert data["success"] is False
    assert data["passed_count"] == 0


@pytest.mark.anyio
async def test_submit_compile_error(client):
    """Submit code that fails to compile."""
    code = 'int main() { this is not valid c++; }'
    resp = await client.post("/submit", json={
        "challenge_id": "vars_01",
        "code": code,
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["compiled"] is False
    assert data["success"] is False
    assert len(data["compiler_output"]) > 0


@pytest.mark.anyio
async def test_submit_forbidden_pattern(client):
    """Submit code with a forbidden system call — should be rejected."""
    code = '#include <iostream>\nint main() { system("whoami"); return 0; }'
    resp = await client.post("/submit", json={
        "challenge_id": "vars_01",
        "code": code,
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["compiled"] is False
    assert "Forbidden" in data["compiler_output"]


@pytest.mark.anyio
async def test_submit_invalid_challenge(client):
    """Submit to a challenge that does not exist."""
    code = '#include <iostream>\nint main() { return 0; }'
    resp = await client.post("/submit", json={
        "challenge_id": "nonexistent_99",
        "code": code,
    })
    assert resp.status_code == 404
