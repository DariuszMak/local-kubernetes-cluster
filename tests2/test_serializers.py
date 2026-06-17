import pytest
from hypothesis import given
from hypothesis import strategies as st

from apps.posts.models import Post
from apps.posts.serializers import PostCreateSerializer, PostReadSerializer
from apps.users.models import User


@pytest.mark.django_db
def test_post_read_serializer() -> None:
    user = User.objects.create()
    post = Post.objects.create(
        title="Test title",
        body="Test body",
        user=user,
    )

    serializer = PostReadSerializer(post)

    assert serializer.data == {
        "id": post.id,
        "title": "Test title",
        "body": "Test body",
        "user_id": user.id,
    }


@pytest.mark.django_db
def test_post_create_serializer_valid_data() -> None:
    data = {
        "title": "New post",
        "body": "Some content",
    }

    serializer = PostCreateSerializer(data=data)

    assert serializer.is_valid()
    assert serializer.validated_data == data


@pytest.mark.django_db
def test_post_create_serializer_default_body() -> None:
    data = {
        "title": "New post",
    }

    serializer = PostCreateSerializer(data=data)

    assert serializer.is_valid()
    assert serializer.validated_data["body"] == ""


@pytest.mark.django_db
def test_post_create_serializer_blank_body_allowed() -> None:
    data = {
        "title": "New post",
        "body": "",
    }

    serializer = PostCreateSerializer(data=data)

    assert serializer.is_valid()
    assert serializer.validated_data["body"] == ""


@pytest.mark.django_db
def test_post_create_serializer_missing_title() -> None:
    data = {
        "body": "Content",
    }

    serializer = PostCreateSerializer(data=data)

    assert not serializer.is_valid()
    assert "title" in serializer.errors


@pytest.mark.django_db
def test_post_create_serializer_title_too_long() -> None:
    data = {
        "title": "a" * 256,
        "body": "Content",
    }

    serializer = PostCreateSerializer(data=data)

    assert not serializer.is_valid()
    assert "title" in serializer.errors


@given(
    title=st.text(min_size=256),
    body=st.text(),
)
@pytest.mark.django_db
def test_post_create_serializer_rejects_long_title(title: str, body: str) -> None:
    data = {"title": title, "body": body}

    serializer = PostCreateSerializer(data=data)

    assert not serializer.is_valid()
    assert "title" in serializer.errors


@given(body=st.text())
@pytest.mark.django_db
def test_post_create_serializer_rejects_missing_title(body: str) -> None:
    data = {"body": body}

    serializer = PostCreateSerializer(data=data)

    assert not serializer.is_valid()
    assert "title" in serializer.errors
