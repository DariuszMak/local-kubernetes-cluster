import asyncio

import pytest
from fastapi.testclient import TestClient
from httpx import ASGITransport, AsyncClient
from hypothesis import given, settings
from hypothesis import strategies as st

from src2.main import app
from tests2.conftest import reset_db


def test_root(client: TestClient) -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert response.json()["message"] == "API playground is running"


def test_health(client: TestClient) -> None:
    response = client.get("/health/")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_liveness(client: TestClient) -> None:
    response = client.get("/health/liveness")

    assert response.status_code == 200
    assert response.json() == {"status": "alive"}


def test_readiness(client: TestClient) -> None:
    response = client.get("/health/readiness")

    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_openapi_schema(client: TestClient) -> None:
    response = client.get("/openapi.json")

    assert response.status_code == 200
    assert "paths" in response.json()


def test_favicon(client: TestClient) -> None:
    response = client.get("/favicon.ico")

    assert response.status_code == 200


def test_protected_route_requires_token() -> None:
    client = TestClient(app)

    response = client.get("/users/1")

    assert response.status_code in (401, 403)


def test_protected_route_with_token() -> None:
    client = TestClient(app)

    login = client.post(
        "/auth/login",
        data={"username": "secure@test.com", "password": "test"},
    )
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    response = client.get("/users/999", headers=headers)

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_login_returns_token() -> None:
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/auth/login",
            data={"username": "test@example.com", "password": "test"},
        )

    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"  # noqa: S105


@pytest.mark.asyncio
async def test_protected_endpoint_requires_token() -> None:
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/users/1")

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_protected_endpoint_with_valid_token() -> None:
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        login_response = await client.post(
            "/auth/login",
            data={"username": "test@example.com", "password": "test"},
        )

        token = login_response.json()["access_token"]

        response = await client.get(
            "/users/1",
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code != 401


@pytest.mark.asyncio
async def test_protected_endpoint_with_invalid_token() -> None:
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/users/1",
            headers={"Authorization": "Bearer invalidtoken"},
        )

    assert response.status_code == 401


@settings(deadline=None)
@given(email=st.emails())
def test_users_endpoint_roundtrip_property(email: str) -> None:
    asyncio.run(reset_db())

    client = TestClient(app)

    create_response = client.post(
        "/users/",
        params={"email": email},
    )

    assert create_response.status_code == 200

    created_user = create_response.json()
    user_id = created_user["id"]

    login_response = client.post(
        "/auth/login",
        data={"username": email, "password": "test"},
    )

    assert login_response.status_code == 200

    token = login_response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    response = client.get(f"/users/{user_id}", headers=headers)

    assert response.status_code == 200
    assert response.json()["email"] == email


def _create_user_and_token(client: TestClient, email: str) -> tuple[int, str]:
    resp = client.post("/users/", params={"email": email})
    assert resp.status_code == 200
    user_id: int = resp.json()["id"]

    login = client.post("/auth/login", data={"username": email, "password": "x"})
    assert login.status_code == 200
    token: str = login.json()["access_token"]
    return user_id, token


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_create_post(client: TestClient) -> None:
    user_id, token = _create_user_and_token(client, "cp@test.com")

    resp = client.post(
        f"/users/{user_id}/posts/",
        json={"title": "My First Post", "body": "Hello!"},
        headers=_auth(token),
    )

    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "My First Post"
    assert data["body"] == "Hello!"
    assert data["user_id"] == user_id
    assert isinstance(data["id"], int)


def test_list_posts_empty(client: TestClient) -> None:
    user_id, token = _create_user_and_token(client, "lp_empty@test.com")

    resp = client.get(f"/users/{user_id}/posts/", headers=_auth(token))

    assert resp.status_code == 200
    assert resp.json() == []


def test_list_posts_after_create(client: TestClient) -> None:
    user_id, token = _create_user_and_token(client, "lp_after@test.com")
    headers = _auth(token)

    client.post(f"/users/{user_id}/posts/", json={"title": "A"}, headers=headers)
    client.post(f"/users/{user_id}/posts/", json={"title": "B"}, headers=headers)

    resp = client.get(f"/users/{user_id}/posts/", headers=headers)

    assert resp.status_code == 200
    titles = {p["title"] for p in resp.json()}
    assert titles == {"A", "B"}


def test_get_post_by_id(client: TestClient) -> None:
    user_id, token = _create_user_and_token(client, "gp@test.com")
    headers = _auth(token)

    created = client.post(
        f"/users/{user_id}/posts/",
        json={"title": "Fetchable"},
        headers=headers,
    ).json()

    resp = client.get(f"/users/{user_id}/posts/{created['id']}", headers=headers)

    assert resp.status_code == 200
    assert resp.json()["id"] == created["id"]


def test_get_post_not_found(client: TestClient) -> None:
    user_id, token = _create_user_and_token(client, "gp_404@test.com")

    resp = client.get(f"/users/{user_id}/posts/999999", headers=_auth(token))

    assert resp.status_code == 404


def test_delete_post(client: TestClient) -> None:
    user_id, token = _create_user_and_token(client, "dp@test.com")
    headers = _auth(token)

    created = client.post(
        f"/users/{user_id}/posts/",
        json={"title": "To Delete"},
        headers=headers,
    ).json()
    post_id = created["id"]

    resp = client.delete(f"/users/{user_id}/posts/{post_id}", headers=headers)
    assert resp.status_code == 204

    resp = client.get(f"/users/{user_id}/posts/{post_id}", headers=headers)
    assert resp.status_code == 404


def test_delete_post_not_found(client: TestClient) -> None:
    user_id, token = _create_user_and_token(client, "dp_404@test.com")

    resp = client.delete(f"/users/{user_id}/posts/999999", headers=_auth(token))

    assert resp.status_code == 404


def test_posts_require_auth(client: TestClient) -> None:
    resp = client.get("/users/1/posts/")
    assert resp.status_code == 401

    resp = client.post("/users/1/posts/", json={"title": "x"})
    assert resp.status_code == 401


def test_create_post_default_body(client: TestClient) -> None:
    user_id, token = _create_user_and_token(client, "default_body@test.com")

    resp = client.post(
        f"/users/{user_id}/posts/",
        json={"title": "No Body"},
        headers=_auth(token),
    )

    assert resp.status_code == 200
    assert resp.json()["body"] == ""


@pytest.mark.asyncio
async def test_post_roundtrip_async() -> None:
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user_resp = await client.post("/users/", params={"email": "async_post@test.com"})
        user_id = user_resp.json()["id"]

        login = await client.post(
            "/auth/login",
            data={"username": "async_post@test.com", "password": "x"},
        )
        token = login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        create_resp = await client.post(
            f"/users/{user_id}/posts/",
            json={"title": "Async Title", "body": "Async Body"},
            headers=headers,
        )
        assert create_resp.status_code == 200
        post_id = create_resp.json()["id"]

        get_resp = await client.get(
            f"/users/{user_id}/posts/{post_id}",
            headers=headers,
        )
        assert get_resp.status_code == 200
        assert get_resp.json()["title"] == "Async Title"


def test_post_create_list_property() -> None:
    from hypothesis import given, settings
    from hypothesis import strategies as st

    @settings(deadline=None, max_examples=5)
    @given(
        titles=st.lists(
            st.text(min_size=1, max_size=100, alphabet=st.characters(whitelist_categories=("Lu", "Ll", "Nd", "Zs"))),
            min_size=1,
            max_size=4,
            unique=True,
        )
    )
    def inner(titles: list[str]) -> None:
        asyncio.run(reset_db())
        c = TestClient(app)

        resp = c.post("/users/", params={"email": "prop_api@test.com"})
        user_id = resp.json()["id"]
        login = c.post("/auth/login", data={"username": "prop_api@test.com", "password": "x"})
        token = login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        for title in titles:
            c.post(f"/users/{user_id}/posts/", json={"title": title}, headers=headers)

        list_resp = c.get(f"/users/{user_id}/posts/", headers=headers)
        assert list_resp.status_code == 200
        assert len(list_resp.json()) == len(titles)

    inner()
