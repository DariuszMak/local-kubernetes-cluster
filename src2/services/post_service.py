from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from src2.db.models.post import Post
    from src2.repositories.post_repository import PostRepository


class PostNotFoundError(Exception):
    pass


class PostService:
    def __init__(self, repository: PostRepository) -> None:
        self._repository = repository

    async def create_post(self, user_id: int, title: str, body: str = "") -> Post:
        return await self._repository.create(user_id=user_id, title=title, body=body)

    async def get_post(self, post_id: int) -> Post:
        post = await self._repository.get_by_id(post_id)
        if not post:
            raise PostNotFoundError(f"Post with id {post_id} not found")
        return post

    async def get_posts_for_user(self, user_id: int) -> list[Post]:
        return await self._repository.get_by_user_id(user_id)

    async def delete_post(self, post_id: int) -> None:
        post = await self._repository.get_by_id(post_id)
        if not post:
            raise PostNotFoundError(f"Post with id {post_id} not found")
        await self._repository.delete(post)
