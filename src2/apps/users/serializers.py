from typing import ClassVar

from apps.users.models import User
from rest_framework import serializers


class UserReadSerializer(serializers.ModelSerializer[User]):
    class Meta:
        model = User
        fields: ClassVar[list[str]] = ["id", "email"]
