from typing import TYPE_CHECKING

from fastapi import APIRouter, Depends
from fastapi.security import OAuth2PasswordRequestForm

from src.api.dependencies.auth import get_auth_service

if TYPE_CHECKING:
    from src.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login")
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),  # noqa: B008
    service: AuthService = Depends(get_auth_service),  # noqa: B008
) -> dict[str, str]:
    token = service.create_token_for_user(form_data.username)
    return {"access_token": token, "token_type": "bearer"}
