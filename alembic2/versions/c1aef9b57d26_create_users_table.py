from typing import TYPE_CHECKING

import sqlalchemy as sa
from sqlalchemy import Integer, String, column, table

from alembic import op

if TYPE_CHECKING:
    from collections.abc import Sequence

revision: str = "309d74cfd942"
down_revision: str | Sequence[str] | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False, unique=True),
    )
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)

    users_table = table(
        "users",
        column("id", Integer),
        column("email", String),
    )

    op.bulk_insert(
        users_table,
        [{"id": 1, "email": "admin@example.com"}],
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_table("users")
