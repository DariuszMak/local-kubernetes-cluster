from typing import TYPE_CHECKING

from sqlalchemy import select

from src2.db.models.post import Post

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession


class PostRepository:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_by_id(self, post_id: int) -> Post | None:
        result = await self._db.execute(select(Post).where(Post.id == post_id))
        return result.scalar_one_or_none()

    async def get_by_user_id(self, user_id: int) -> list[Post]:
        result = await self._db.execute(select(Post).where(Post.user_id == user_id))
        return list(result.scalars().all())

    async def create(self, user_id: int, title: str, body: str = "") -> Post:
        post = Post(user_id=user_id, title=title, body=body)
        self._db.add(post)
        await self._db.commit()
        await self._db.refresh(post)
        return post

    async def delete(self, post: Post) -> None:
        await self._db.delete(post)
        await self._db.commit()
