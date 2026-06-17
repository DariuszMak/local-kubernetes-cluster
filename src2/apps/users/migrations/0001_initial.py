from typing import ClassVar

from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies: ClassVar[list[tuple[str, str]]] = []

    operations: ClassVar[list[migrations.operations.base.Operation]] = [
        migrations.CreateModel(
            name="User",
            fields=[
                ("id", models.AutoField(primary_key=True, serialize=False)),
                ("email", models.EmailField(db_index=True, max_length=255, unique=True)),
            ],
            options={
                "db_table": "users",
            },
        ),
        migrations.RunSQL(
            sql="INSERT INTO users (id, email) VALUES (1, 'admin@example.com') ON CONFLICT DO NOTHING;",
            reverse_sql="DELETE FROM users WHERE id = 1;",
        ),
    ]
