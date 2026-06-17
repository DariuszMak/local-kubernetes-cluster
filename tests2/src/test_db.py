from typing import TYPE_CHECKING

import pytest
from hypothesis import HealthCheck, given, settings
from hypothesis import strategies as st

from src2.repositories.post_repository import PostRepository
from src2.repositories.user_repository import UserRepository
from src2.services.post_service import PostNotFoundError, PostService
from src2.services.user_service import UserService
from tests2.conftest import reset_db
from tests2.utils.db_config import TestingSessionLocal

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession


from typing import TYPE_CHECKING

from src2.helpers.exceptions import DuplicateEmailError

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession


@pytest.mark.asyncio
async def test_create_user(db_session: AsyncSession) -> None:
    repo = UserRepository(db_session)
    service = UserService(repo)
    email = "test@example.com"

    user = await service.create_user(email)

    assert user.id is not None
    assert user.email == email


@pytest.mark.asyncio
async def test_get_user_by_id_existing(db_session: AsyncSession) -> None:
    repo = UserRepository(db_session)
    service = UserService(repo)
    email = "existing@example.com"

    created_user = await service.create_user(email)

    fetched_user = await repo.get_by_id(created_user.id)

    assert fetched_user is not None
    assert fetched_user.id == created_user.id
    assert fetched_user.email == email


@pytest.mark.asyncio
async def test_get_user_by_id_not_existing(db_session: AsyncSession) -> None:
    repo = UserRepository(db_session)

    user = await repo.get_by_id(999999)

    assert user is None


@pytest.mark.asyncio
async def test_create_multiple_users(db_session: AsyncSession) -> None:
    repo = UserRepository(db_session)
    service = UserService(repo)

    user1 = await service.create_user("user1@example.com")
    user2 = await service.create_user("user2@example.com")

    assert user1.id is not None
    assert user2.id is not None
    assert user1.id != user2.id
    assert user1.email == "user1@example.com"
    assert user2.email == "user2@example.com"


@pytest.mark.asyncio
async def test_repository_create_direct(db_session: AsyncSession) -> None:
    repo = UserRepository(db_session)

    user = await repo.create("repo@example.com")

    assert user.id is not None
    assert user.email == "repo@example.com"


@pytest.mark.asyncio
async def test_user_persisted_after_commit(db_session: AsyncSession) -> None:
    repo = UserRepository(db_session)

    created = await repo.create("persist@example.com")

    fetched = await repo.get_by_id(created.id)

    assert fetched is not None
    assert fetched.email == "persist@example.com"


@pytest.mark.asyncio
@settings(deadline=None)
@given(email=st.emails())
async def test_create_user_property(email: str) -> None:
    await reset_db()

    async with TestingSessionLocal() as session:
        repo = UserRepository(session)
        service = UserService(repo)

        user = await service.create_user(email)

        assert user.id is not None
        assert user.email == email


@pytest.mark.asyncio
@settings(suppress_health_check=[HealthCheck.function_scoped_fixture], deadline=None)
@given(email=st.emails())
async def test_duplicate_email_property(email: str) -> None:
    await reset_db()

    async with TestingSessionLocal() as session:
        repo = UserRepository(session)

        await repo.create(email)

        with pytest.raises(DuplicateEmailError):
            await repo.create(email)


@pytest.mark.asyncio
@settings(deadline=None)
@given(
    emails=st.lists(
        st.emails(),
        min_size=1,
        max_size=5,
        unique=True,
    )
)
async def test_multiple_unique_users_property(emails: list[str]) -> None:
    await reset_db()

    async with TestingSessionLocal() as session:
        repo = UserRepository(session)

        users = [await repo.create(email) for email in emails]

        ids = [u.id for u in users]

        assert len(ids) == len(set(ids))
        assert sorted(u.email for u in users) == sorted(emails)


async def _make_user(db: AsyncSession, email: str = "owner@example.com") -> int:
    repo = UserRepository(db)
    user = await UserService(repo).create_user(email)
    return user.id


@pytest.mark.asyncio
async def test_create_post(db_session: AsyncSession) -> None:
    user_id = await _make_user(db_session, "create_post@example.com")
    repo = PostRepository(db_session)
    service = PostService(repo)

    post = await service.create_post(user_id=user_id, title="Hello", body="World")

    assert post.id is not None
    assert post.title == "Hello"
    assert post.body == "World"
    assert post.user_id == user_id


@pytest.mark.asyncio
async def test_get_post_by_id(db_session: AsyncSession) -> None:
    user_id = await _make_user(db_session, "get_post@example.com")
    repo = PostRepository(db_session)
    service = PostService(repo)

    created = await service.create_post(user_id=user_id, title="Fetch me")
    fetched = await service.get_post(created.id)

    assert fetched.id == created.id
    assert fetched.title == "Fetch me"


@pytest.mark.asyncio
async def test_get_post_not_found_raises(db_session: AsyncSession) -> None:
    repo = PostRepository(db_session)
    service = PostService(repo)

    with pytest.raises(PostNotFoundError):
        await service.get_post(999999)


@pytest.mark.asyncio
async def test_list_posts_for_user(db_session: AsyncSession) -> None:
    user_id = await _make_user(db_session, "list_posts@example.com")
    repo = PostRepository(db_session)
    service = PostService(repo)

    await service.create_post(user_id=user_id, title="Post A")
    await service.create_post(user_id=user_id, title="Post B")

    posts = await service.get_posts_for_user(user_id)

    assert len(posts) == 2
    titles = {p.title for p in posts}
    assert titles == {"Post A", "Post B"}


@pytest.mark.asyncio
async def test_list_posts_empty_for_new_user(db_session: AsyncSession) -> None:
    user_id = await _make_user(db_session, "empty_posts@example.com")
    repo = PostRepository(db_session)
    service = PostService(repo)

    posts = await service.get_posts_for_user(user_id)

    assert posts == []


@pytest.mark.asyncio
async def test_posts_belong_to_correct_user(db_session: AsyncSession) -> None:
    user_repo = UserRepository(db_session)
    u1 = await UserService(user_repo).create_user("u1_posts@example.com")
    u2 = await UserService(user_repo).create_user("u2_posts@example.com")

    post_repo = PostRepository(db_session)
    service = PostService(post_repo)

    await service.create_post(user_id=u1.id, title="U1 Post")
    await service.create_post(user_id=u2.id, title="U2 Post")

    u1_posts = await service.get_posts_for_user(u1.id)
    u2_posts = await service.get_posts_for_user(u2.id)

    assert all(p.user_id == u1.id for p in u1_posts)
    assert all(p.user_id == u2.id for p in u2_posts)


@pytest.mark.asyncio
async def test_delete_post(db_session: AsyncSession) -> None:
    user_id = await _make_user(db_session, "delete_post@example.com")
    repo = PostRepository(db_session)
    service = PostService(repo)

    post = await service.create_post(user_id=user_id, title="To Delete")
    post_id = post.id

    await service.delete_post(post_id)

    with pytest.raises(PostNotFoundError):
        await service.get_post(post_id)


@pytest.mark.asyncio
async def test_delete_nonexistent_post_raises(db_session: AsyncSession) -> None:
    repo = PostRepository(db_session)
    service = PostService(repo)

    with pytest.raises(PostNotFoundError):
        await service.delete_post(999999)


@pytest.mark.asyncio
async def test_post_default_body_is_empty(db_session: AsyncSession) -> None:
    user_id = await _make_user(db_session, "default_body@example.com")
    repo = PostRepository(db_session)
    service = PostService(repo)

    post = await service.create_post(user_id=user_id, title="No body")

    assert post.body == ""


@pytest.mark.asyncio
@settings(deadline=None)
@given(title=st.text(min_size=1, max_size=255))
async def test_post_title_roundtrip_property(title: str) -> None:
    await reset_db()

    async with TestingSessionLocal() as session:
        user_id = await _make_user(session, "prop_title@example.com")
        repo = PostRepository(session)
        service = PostService(repo)

        post = await service.create_post(user_id=user_id, title=title)

        assert post.title == title


@pytest.mark.asyncio
@settings(suppress_health_check=[HealthCheck.function_scoped_fixture], deadline=None)
@given(count=st.integers(min_value=1, max_value=6))
async def test_post_count_property(count: int) -> None:
    await reset_db()

    async with TestingSessionLocal() as session:
        user_id = await _make_user(session, "prop_count@example.com")
        repo = PostRepository(session)
        service = PostService(repo)

        for i in range(count):
            await service.create_post(user_id=user_id, title=f"Post {i}")

        posts = await service.get_posts_for_user(user_id)

        assert len(posts) == count
