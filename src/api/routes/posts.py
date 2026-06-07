from typing import TYPE_CHECKING

from fastapi import APIRouter, Depends, HTTPException

from src.api.dependencies.auth import get_current_user_email
from src.db.session import get_db
from src.repositories.post_repository import PostRepository
from src.schemas.post import PostCreate, PostRead
from src.services.post_service import PostNotFoundError, PostService

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession

    from src.db.models.post import Post

router = APIRouter(prefix="/users/{user_id}/posts", tags=["posts"])


def get_post_service(db: AsyncSession = Depends(get_db)) -> PostService:  # noqa: B008
    repo = PostRepository(db)
    return PostService(repo)


@router.post("/", response_model=PostRead)
async def create_post(
    user_id: int,
    payload: PostCreate,
    _: str = Depends(get_current_user_email),
    service: PostService = Depends(get_post_service),  # noqa: B008
) -> Post:
    return await service.create_post(user_id=user_id, title=payload.title, body=payload.body)


@router.get("/", response_model=list[PostRead])
async def list_posts(
    user_id: int,
    _: str = Depends(get_current_user_email),
    service: PostService = Depends(get_post_service),  # noqa: B008
) -> list[Post]:
    return await service.get_posts_for_user(user_id)


@router.get("/{post_id}", response_model=PostRead)
async def get_post(
    user_id: int,  # noqa: ARG001
    post_id: int,
    _: str = Depends(get_current_user_email),
    service: PostService = Depends(get_post_service),  # noqa: B008
) -> Post:
    try:
        return await service.get_post(post_id)
    except PostNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete("/{post_id}", status_code=204)
async def delete_post(
    user_id: int,  # noqa: ARG001
    post_id: int,
    _: str = Depends(get_current_user_email),
    service: PostService = Depends(get_post_service),  # noqa: B008
) -> None:
    try:
        await service.delete_post(post_id)
    except PostNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
