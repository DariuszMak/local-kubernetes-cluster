from typing import TYPE_CHECKING

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession

from src.api.dependencies.auth import get_current_user_email
from src.db.session import get_db
from src.helpers.exceptions import DuplicateEmailError
from src.repositories.user_repository import UserRepository
from src.services.user_service import UserNotFoundError, UserService

if TYPE_CHECKING:
    from src.db.models.user import User

router = APIRouter(prefix="/users", tags=["users"])


class UserRead(BaseModel):
    id: int
    email: str

    model_config = ConfigDict(from_attributes=True)


def get_user_service(db: AsyncSession = Depends(get_db)) -> UserService:  # noqa: B008
    repo = UserRepository(db)
    return UserService(repo)


@router.post("/", response_model=UserRead)
async def create_user(
    email: str,
    service: UserService = Depends(get_user_service),  # noqa: B008
) -> User:
    try:
        return await service.create_user(email)
    except DuplicateEmailError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


@router.get("/{user_id}", response_model=UserRead)
async def get_user(
    user_id: int,
    _: str = Depends(get_current_user_email),
    service: UserService = Depends(get_user_service),  # noqa: B008
) -> User:
    try:
        return await service.get_user(user_id)
    except UserNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
