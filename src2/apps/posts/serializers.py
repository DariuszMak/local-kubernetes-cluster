from typing import ClassVar

from apps.posts.models import Post
from rest_framework import serializers


class PostReadSerializer(serializers.ModelSerializer[Post]):
    class Meta:
        model = Post
        fields: ClassVar[list[str]] = ["id", "title", "body", "user_id"]


class PostCreateSerializer(serializers.Serializer[Post]):
    title = serializers.CharField(max_length=255)
    body = serializers.CharField(default="", allow_blank=True)
