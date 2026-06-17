from typing import TYPE_CHECKING

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from src2.db.models.user import User
from src2.helpers.exceptions import DuplicateEmailError

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession


class UserRepository:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_by_id(self, user_id: int) -> User | None:
        result = await self._db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def create(self, email: str) -> User:
        user = User(email=email)
        self._db.add(user)

        try:
            await self._db.commit()
        except IntegrityError as exc:
            await self._db.rollback()
            raise DuplicateEmailError(email=email) from exc

        await self._db.refresh(user)
        return user
