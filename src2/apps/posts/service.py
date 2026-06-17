from typing import TYPE_CHECKING

from apps.posts.repository import PostRepository

if TYPE_CHECKING:
    from apps.posts.models import Post


class PostNotFoundError(Exception):
    pass


class PostService:
    def __init__(self, repository: PostRepository | None = None) -> None:
        self._repository = repository or PostRepository()

    def create_post(self, user_id: int, title: str, body: str = "") -> Post:
        return self._repository.create(user_id=user_id, title=title, body=body)

    def get_post(self, post_id: int) -> Post:
        post = self._repository.get_by_id(post_id)
        if not post:
            raise PostNotFoundError(f"Post with id {post_id} not found")
        return post

    def get_posts_for_user(self, user_id: int) -> list[Post]:
        return self._repository.get_by_user_id(user_id)

    def delete_post(self, post_id: int) -> None:
        post = self._repository.get_by_id(post_id)
        if not post:
            raise PostNotFoundError(f"Post with id {post_id} not found")
        self._repository.delete(post)
