from django.db import models


class User(models.Model):
    email = models.EmailField(max_length=255, unique=True, db_index=True)

    class Meta:
        db_table = "users"

    def __str__(self) -> str:
        return self.email
