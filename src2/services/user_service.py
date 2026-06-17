from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from src2.db.models.user import User
    from src2.repositories.user_repository import UserRepository


class UserNotFoundError(Exception):
    pass


class UserService:
    def __init__(self, repository: UserRepository) -> None:
        self._repository = repository

    async def create_user(self, email: str) -> User:
        return await self._repository.create(email)

    async def get_user(self, user_id: int) -> User:
        user = await self._repository.get_by_id(user_id)
        if not user:
            raise UserNotFoundError(f"User with id {user_id} not found")
        return user
