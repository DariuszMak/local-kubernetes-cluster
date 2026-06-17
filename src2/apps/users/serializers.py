from typing import ClassVar

from rest_framework import serializers

from apps.users.models import User


class UserReadSerializer(serializers.ModelSerializer[User]):
    class Meta:
        model = User
        fields: ClassVar[list[str]] = ["id", "email"]
