from typing import ClassVar

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies: ClassVar[list[tuple[str, str]]] = [
        ("users", "0001_initial"),
    ]

    operations: ClassVar[list[migrations.operations.base.Operation]] = [
        migrations.CreateModel(
            name="Post",
            fields=[
                ("id", models.AutoField(primary_key=True, serialize=False)),
                ("title", models.CharField(max_length=255)),
                ("body", models.TextField(default="", blank=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="posts",
                        to="users.user",
                    ),
                ),
            ],
            options={"db_table": "posts"},
        ),
    ]
