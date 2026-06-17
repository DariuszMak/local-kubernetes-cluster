import pytest
from apps.posts.models import Post
from apps.users.models import User
from apps.users.repository import UserRepository
from django.test import Client
from hypothesis import given, settings
from hypothesis import strategies as st


@pytest.mark.django_db
def test_root(client: Client) -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert response.json()["message"] == "API playground is running"


@pytest.mark.django_db
def test_health(client: Client) -> None:
    response = client.get("/health/")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.django_db
def test_liveness(client: Client) -> None:
    response = client.get("/health/liveness")

    assert response.status_code == 200
    assert response.json() == {"status": "alive"}


@pytest.mark.django_db
def test_readiness(client: Client) -> None:
    response = client.get("/health/readiness")

    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


@pytest.mark.django_db
def test_openapi_schema(client: Client) -> None:
    response = client.get("/openapi.json")

    assert response.status_code == 200
    data = response.json()
    assert "paths" in data
    assert data["openapi"].startswith("3.")


@pytest.mark.django_db
def test_login_returns_token(client: Client) -> None:
    response = client.post(
        "/auth/login",
        data={"username": "test@example.com", "password": "test"},
    )

    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert isinstance(data["access_token"], str)
    assert data["access_token"]
    assert data["token_type"] == "bearer"  # noqa: S105


@pytest.mark.django_db
def test_login_missing_username_returns_422(client: Client) -> None:
    response = client.post(
        "/auth/login",
        data={},
    )

    assert response.status_code == 422


@pytest.mark.django_db
def test_protected_route_requires_token(client: Client) -> None:
    response = client.get("/users/1")

    assert response.status_code == 401


@pytest.mark.django_db
def test_protected_route_with_invalid_token(client: Client) -> None:
    response = client.get(
        "/users/1",
        HTTP_AUTHORIZATION="Bearer invalidtoken",
    )

    assert response.status_code == 401


@pytest.mark.django_db
def test_protected_route_valid_token_nonexistent_user(client: Client) -> None:
    login = client.post(
        "/auth/login",
        data={"username": "secure@test.com", "password": "test"},
    )
    token = login.json()["access_token"]

    response = client.get(
        "/users/999999",
        HTTP_AUTHORIZATION=f"Bearer {token}",
    )

    assert response.status_code == 404


@pytest.mark.django_db
def test_create_user(client: Client) -> None:
    response = client.post("/users/?email=newuser@example.com")

    assert response.status_code == 200
    data = response.json()
    assert isinstance(data["id"], int)
    assert data["email"] == "newuser@example.com"


@pytest.mark.django_db
def test_create_duplicate_user_returns_500(client: Client) -> None:
    client.post("/users/?email=dup@example.com")
    response = client.post("/users/?email=dup@example.com")

    assert response.status_code == 500


@pytest.mark.django_db
def test_get_user_requires_auth(client: Client) -> None:
    create = client.post("/users/?email=auth@example.com")
    user_id = create.json()["id"]

    response = client.get(f"/users/{user_id}")

    assert response.status_code == 401


@pytest.mark.django_db
def test_get_user_returns_correct_data(client: Client) -> None:
    email = "getme@example.com"
    create = client.post(f"/users/?email={email}")
    user_id = create.json()["id"]

    login = client.post(
        "/auth/login",
        data={"username": email, "password": "x"},
    )
    token = login.json()["access_token"]

    response = client.get(
        f"/users/{user_id}",
        HTTP_AUTHORIZATION=f"Bearer {token}",
    )

    assert response.status_code == 200
    data = response.json()
    assert data["id"] == user_id
    assert data["email"] == email


@pytest.mark.django_db
def test_get_nonexistent_user_returns_404(client: Client) -> None:
    login = client.post(
        "/auth/login",
        data={"username": "anyone@example.com", "password": "x"},
    )
    token = login.json()["access_token"]

    response = client.get(
        "/users/999999",
        HTTP_AUTHORIZATION=f"Bearer {token}",
    )

    assert response.status_code == 404


_SAFE_LOCAL = st.text(
    alphabet=st.sampled_from("abcdefghijklmnopqrstuvwxyz0123456789._%+-"),
    min_size=1,
    max_size=20,
)
_SAFE_DOMAIN = st.text(
    alphabet=st.sampled_from("abcdefghijklmnopqrstuvwxyz0123456789-"),
    min_size=2,
    max_size=10,
)
_SAFE_TLD = st.text(
    alphabet=st.sampled_from("abcdefghijklmnopqrstuvwxyz"),
    min_size=2,
    max_size=4,
)
_django_safe_emails = st.builds(
    lambda local, domain, tld: f"{local}@{domain}.{tld}",
    local=_SAFE_LOCAL,
    domain=_SAFE_DOMAIN,
    tld=_SAFE_TLD,
)


@pytest.mark.django_db(transaction=True)
@settings(max_examples=10, deadline=None)
@given(email=_django_safe_emails)
def test_users_endpoint_roundtrip_property(email: str) -> None:
    User.objects.all().delete()

    c = Client()

    create_response = c.post("/users/", data={"email": email})
    assert create_response.status_code == 200
    user_id = create_response.json()["id"]

    login_response = c.post(
        "/auth/login",
        data={"username": email, "password": "test"},
    )
    assert login_response.status_code == 200
    token = login_response.json()["access_token"]

    get_response = c.get(
        f"/users/{user_id}",
        HTTP_AUTHORIZATION=f"Bearer {token}",
    )
    assert get_response.status_code == 200
    assert get_response.json()["email"] == email


def _create_user_and_token(client: Client, email: str) -> tuple[int, str]:
    resp = client.post(f"/users/?email={email}")
    assert resp.status_code == 200
    user_id: int = resp.json()["id"]

    login = client.post(
        "/auth/login",
        data={"username": email, "password": "x"},
        content_type="application/json",
    )
    assert login.status_code == 200
    token: str = login.json()["access_token"]
    return user_id, token


def _auth(token: str) -> str:
    return f"Bearer {token}"


@pytest.mark.django_db
def test_create_post(client: Client) -> None:
    user_id, token = _create_user_and_token(client, "cp@test.com")

    resp = client.post(
        f"/users/{user_id}/posts/",
        data={"title": "My First Post", "body": "Hello!"},
        content_type="application/json",
        HTTP_AUTHORIZATION=_auth(token),
    )

    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "My First Post"
    assert data["body"] == "Hello!"
    assert data["user_id"] == user_id
    assert isinstance(data["id"], int)


@pytest.mark.django_db
def test_create_post_default_body(client: Client) -> None:
    user_id, token = _create_user_and_token(client, "default_body@test.com")

    resp = client.post(
        f"/users/{user_id}/posts/",
        data={"title": "No Body"},
        content_type="application/json",
        HTTP_AUTHORIZATION=_auth(token),
    )

    assert resp.status_code == 200
    assert resp.json()["body"] == ""


@pytest.mark.django_db
def test_create_post_missing_title_returns_422(client: Client) -> None:
    user_id, token = _create_user_and_token(client, "no_title@test.com")

    resp = client.post(
        f"/users/{user_id}/posts/",
        data={"body": "no title"},
        content_type="application/json",
        HTTP_AUTHORIZATION=_auth(token),
    )

    assert resp.status_code == 422


@pytest.mark.django_db
def test_list_posts_empty(client: Client) -> None:
    user_id, token = _create_user_and_token(client, "lp_empty@test.com")

    resp = client.get(
        f"/users/{user_id}/posts/",
        HTTP_AUTHORIZATION=_auth(token),
    )

    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.django_db
def test_list_posts_after_create(client: Client) -> None:
    user_id, token = _create_user_and_token(client, "lp_after@test.com")

    for title in ("A", "B"):
        client.post(
            f"/users/{user_id}/posts/",
            data={"title": title},
            content_type="application/json",
            HTTP_AUTHORIZATION=_auth(token),
        )

    resp = client.get(
        f"/users/{user_id}/posts/",
        HTTP_AUTHORIZATION=_auth(token),
    )

    assert resp.status_code == 200
    assert {p["title"] for p in resp.json()} == {"A", "B"}


@pytest.mark.django_db
def test_get_post_by_id(client: Client) -> None:
    user_id, token = _create_user_and_token(client, "gp@test.com")

    created = client.post(
        f"/users/{user_id}/posts/",
        data={"title": "Fetchable"},
        content_type="application/json",
        HTTP_AUTHORIZATION=_auth(token),
    ).json()

    resp = client.get(
        f"/users/{user_id}/posts/{created['id']}",
        HTTP_AUTHORIZATION=_auth(token),
    )

    assert resp.status_code == 200
    assert resp.json()["id"] == created["id"]


@pytest.mark.django_db
def test_get_post_not_found(client: Client) -> None:
    user_id, token = _create_user_and_token(client, "gp_404@test.com")

    resp = client.get(
        f"/users/{user_id}/posts/999999",
        HTTP_AUTHORIZATION=_auth(token),
    )

    assert resp.status_code == 404


@pytest.mark.django_db
def test_delete_post(client: Client) -> None:
    user_id, token = _create_user_and_token(client, "dp@test.com")

    created = client.post(
        f"/users/{user_id}/posts/",
        data={"title": "To Delete"},
        content_type="application/json",
        HTTP_AUTHORIZATION=_auth(token),
    ).json()
    post_id = created["id"]

    resp = client.delete(
        f"/users/{user_id}/posts/{post_id}",
        HTTP_AUTHORIZATION=_auth(token),
    )
    assert resp.status_code == 204

    resp = client.get(
        f"/users/{user_id}/posts/{post_id}",
        HTTP_AUTHORIZATION=_auth(token),
    )
    assert resp.status_code == 404


@pytest.mark.django_db
def test_delete_post_not_found(client: Client) -> None:
    user_id, token = _create_user_and_token(client, "dp_404@test.com")

    resp = client.delete(
        f"/users/{user_id}/posts/999999",
        HTTP_AUTHORIZATION=_auth(token),
    )

    assert resp.status_code == 404


@pytest.mark.django_db
def test_posts_list_requires_auth(client: Client) -> None:
    resp = client.get("/users/1/posts/")
    assert resp.status_code == 401


@pytest.mark.django_db
def test_post_create_requires_auth(client: Client) -> None:
    resp = client.post(
        "/users/1/posts/",
        data={"title": "x"},
        content_type="application/json",
    )
    assert resp.status_code == 401


@pytest.mark.django_db
def test_posts_invalid_token_returns_401(client: Client) -> None:
    resp = client.get(
        "/users/1/posts/",
        HTTP_AUTHORIZATION="Bearer invalid.token",
    )
    assert resp.status_code == 401


_SAFE_TITLE = st.text(
    alphabet=st.sampled_from("abcdefghijklmnopqrstuvwxyz0123456789 "),
    min_size=1,
    max_size=50,
)


@pytest.mark.django_db(transaction=True)
@settings(max_examples=10, deadline=None)
@given(
    titles=st.lists(_SAFE_TITLE, min_size=1, max_size=4, unique=True),
)
def test_post_create_list_roundtrip_property(titles: list[str]) -> None:
    Post.objects.all().delete()
    User.objects.all().delete()

    c = Client()
    user = UserRepository().create("prop_api@test.com")

    login = c.post(
        "/auth/login",
        data={"username": user.email, "password": "x"},
        content_type="application/json",
    )
    token = login.json()["access_token"]
    auth_header = f"Bearer {token}"

    for title in titles:
        c.post(
            f"/users/{user.id}/posts/",
            data={"title": title},
            content_type="application/json",
            HTTP_AUTHORIZATION=auth_header,
        )

    resp = c.get(
        f"/users/{user.id}/posts/",
        HTTP_AUTHORIZATION=auth_header,
    )

    assert resp.status_code == 200

    returned = [item["title"] for item in resp.json()]
    expected = [t.strip() for t in titles if t.strip()]

    assert sorted(returned) == sorted(expected)
