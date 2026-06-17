from django.db import models

from apps.users.models import User


class Post(models.Model):
    title = models.CharField(max_length=255)
    body = models.TextField(default="", blank=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="posts")

    class Meta:
        db_table = "posts"

    def __str__(self) -> str:
        return self.title
