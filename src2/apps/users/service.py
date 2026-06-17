from typing import TYPE_CHECKING

from apps.users.repository import UserRepository

if TYPE_CHECKING:
    from apps.users.models import User


class UserNotFoundError(Exception):
    pass


class UserService:
    def __init__(self, repository: UserRepository | None = None) -> None:
        self._repository = repository or UserRepository()

    def create_user(self, email: str) -> User:
        return self._repository.create(email)

    def get_user(self, user_id: int) -> User:
        user = self._repository.get_by_id(user_id)
        if not user:
            raise UserNotFoundError(f"User with id {user_id} not found")
        return user
