from typing import TYPE_CHECKING

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src2.db.base import Base

if TYPE_CHECKING:
    from src2.db.models.post import Post


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)

    posts: Mapped[list[Post]] = relationship(
        "Post",
        back_populates="user",
        cascade="all, delete-orphan",
    )
