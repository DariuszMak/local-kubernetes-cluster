from core.exceptions import DuplicateEmailError
from django.db import IntegrityError

from apps.users.models import User


class UserRepository:
    def get_by_id(self, user_id: int) -> User | None:
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None

    def create(self, email: str) -> User:
        try:
            return User.objects.create(email=email)
        except IntegrityError as exc:
            raise DuplicateEmailError(email=email) from exc
