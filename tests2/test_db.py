import pytest
from apps.posts.models import Post
from apps.posts.repository import PostRepository
from apps.posts.service import PostNotFoundError, PostService
from apps.users.models import User
from apps.users.repository import UserRepository
from apps.users.service import UserNotFoundError, UserService
from core.exceptions import DuplicateEmailError
from hypothesis import HealthCheck, given, settings
from hypothesis import strategies as st


@pytest.mark.django_db
def test_create_user() -> None:
    repo = UserRepository()
    service = UserService(repo)

    user = service.create_user("test@example.com")

    assert user.id is not None
    assert user.email == "test@example.com"


@pytest.mark.django_db
def test_get_user_by_id_existing() -> None:
    repo = UserRepository()
    service = UserService(repo)

    created = service.create_user("existing@example.com")
    fetched = repo.get_by_id(created.id)

    assert fetched is not None
    assert fetched.id == created.id
    assert fetched.email == "existing@example.com"


@pytest.mark.django_db
def test_get_user_by_id_not_existing() -> None:
    repo = UserRepository()

    user = repo.get_by_id(999999)

    assert user is None


@pytest.mark.django_db
def test_create_multiple_users() -> None:
    repo = UserRepository()
    service = UserService(repo)

    user1 = service.create_user("user1@example.com")
    user2 = service.create_user("user2@example.com")

    assert user1.id is not None
    assert user2.id is not None
    assert user1.id != user2.id
    assert user1.email == "user1@example.com"
    assert user2.email == "user2@example.com"


@pytest.mark.django_db
def test_user_repository_create_direct() -> None:
    repo = UserRepository()

    user = repo.create("repo@example.com")

    assert user.id is not None
    assert user.email == "repo@example.com"


@pytest.mark.django_db
def test_user_persisted_after_save() -> None:
    repo = UserRepository()

    created = repo.create("persist@example.com")
    fetched = repo.get_by_id(created.id)

    assert fetched is not None
    assert fetched.email == "persist@example.com"


@pytest.mark.django_db
def test_get_user_raises_for_missing() -> None:
    service = UserService()

    with pytest.raises(UserNotFoundError):
        service.get_user(999999)


@pytest.mark.django_db
def test_duplicate_email_raises() -> None:
    repo = UserRepository()

    repo.create("dup@example.com")

    with pytest.raises(DuplicateEmailError):
        repo.create("dup@example.com")


@pytest.mark.django_db(transaction=True)
@settings(max_examples=20, deadline=None)
@given(email=st.emails())
def test_create_user_property(email: str) -> None:
    User.objects.all().delete()

    repo = UserRepository()
    service = UserService(repo)

    user = service.create_user(email)

    assert user.id is not None
    assert user.email == email


@pytest.mark.django_db(transaction=True)
@settings(suppress_health_check=[HealthCheck.function_scoped_fixture], max_examples=20, deadline=None)
@given(email=st.emails())
def test_duplicate_email_property(email: str) -> None:
    User.objects.all().delete()

    repo = UserRepository()
    repo.create(email)

    with pytest.raises(DuplicateEmailError):
        repo.create(email)


@pytest.mark.django_db(transaction=True)
@settings(max_examples=20, deadline=None)
@given(
    emails=st.lists(
        st.emails(),
        min_size=1,
        max_size=5,
        unique=True,
    )
)
def test_multiple_unique_users_property(emails: list[str]) -> None:
    User.objects.all().delete()

    repo = UserRepository()

    users = [repo.create(email) for email in emails]
    ids = [u.id for u in users]

    assert len(ids) == len(set(ids))
    assert sorted(u.email for u in users) == sorted(emails)


def _make_user(email: str = "owner@example.com") -> User:
    return UserRepository().create(email)


@pytest.mark.django_db
def test_create_post() -> None:
    user = _make_user("create_post@example.com")
    service = PostService()

    post = service.create_post(user_id=user.id, title="Hello", body="World")

    assert post.id is not None
    assert post.title == "Hello"
    assert post.body == "World"
    assert post.user_id == user.id


@pytest.mark.django_db
def test_get_post_by_id() -> None:
    user = _make_user("get_post@example.com")
    service = PostService()

    created = service.create_post(user_id=user.id, title="Fetch me")
    fetched = service.get_post(created.id)

    assert fetched.id == created.id
    assert fetched.title == "Fetch me"


@pytest.mark.django_db
def test_get_post_not_found_raises() -> None:
    service = PostService()

    with pytest.raises(PostNotFoundError):
        service.get_post(999999)


@pytest.mark.django_db
def test_list_posts_for_user() -> None:
    user = _make_user("list_posts@example.com")
    service = PostService()

    service.create_post(user_id=user.id, title="Post A")
    service.create_post(user_id=user.id, title="Post B")

    posts = service.get_posts_for_user(user.id)

    assert len(posts) == 2
    assert {p.title for p in posts} == {"Post A", "Post B"}


@pytest.mark.django_db
def test_list_posts_empty_for_new_user() -> None:
    user = _make_user("empty_posts@example.com")
    service = PostService()

    posts = service.get_posts_for_user(user.id)

    assert posts == []


@pytest.mark.django_db
def test_posts_belong_to_correct_user() -> None:
    u1 = _make_user("u1@example.com")
    u2 = _make_user("u2@example.com")
    service = PostService()

    service.create_post(user_id=u1.id, title="U1 Post")
    service.create_post(user_id=u2.id, title="U2 Post")

    assert all(p.user_id == u1.id for p in service.get_posts_for_user(u1.id))
    assert all(p.user_id == u2.id for p in service.get_posts_for_user(u2.id))


@pytest.mark.django_db
def test_delete_post() -> None:
    user = _make_user("delete_post@example.com")
    service = PostService()

    post = service.create_post(user_id=user.id, title="To Delete")
    post_id = post.id

    service.delete_post(post_id)

    with pytest.raises(PostNotFoundError):
        service.get_post(post_id)


@pytest.mark.django_db
def test_delete_nonexistent_post_raises() -> None:
    service = PostService()

    with pytest.raises(PostNotFoundError):
        service.delete_post(999999)


@pytest.mark.django_db
def test_post_default_body_is_empty() -> None:
    user = _make_user("default_body@example.com")
    service = PostService()

    post = service.create_post(user_id=user.id, title="No body")

    assert post.body == ""


@pytest.mark.django_db
def test_post_repository_create_direct() -> None:
    user = _make_user("repo_direct@example.com")
    repo = PostRepository()

    post = repo.create(user_id=user.id, title="Direct", body="Via repo")

    assert post.id is not None
    assert post.title == "Direct"


@pytest.mark.django_db
def test_post_persisted_after_save() -> None:
    user = _make_user("persist_post@example.com")
    repo = PostRepository()

    created = repo.create(user_id=user.id, title="Persist me")
    fetched = repo.get_by_id(created.id)

    assert fetched is not None
    assert fetched.title == "Persist me"


@pytest.mark.django_db(transaction=True)
@settings(max_examples=20, deadline=None)
@given(title=st.text(min_size=1, max_size=255))
def test_post_title_roundtrip_property(title: str) -> None:
    Post.objects.all().delete()
    User.objects.all().delete()

    user = UserRepository().create("prop_title@example.com")
    service = PostService()

    post = service.create_post(user_id=user.id, title=title)

    assert post.title == title


@pytest.mark.django_db(transaction=True)
@settings(suppress_health_check=[HealthCheck.function_scoped_fixture], max_examples=10, deadline=None)
@given(count=st.integers(min_value=1, max_value=6))
def test_post_count_property(count: int) -> None:
    Post.objects.all().delete()
    User.objects.all().delete()

    user = UserRepository().create("prop_count@example.com")
    service = PostService()

    for i in range(count):
        service.create_post(user_id=user.id, title=f"Post {i}")

    assert len(service.get_posts_for_user(user.id)) == count
