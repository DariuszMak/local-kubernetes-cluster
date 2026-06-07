from fastapi import APIRouter

from src.schemas.root import RootResponse

router = APIRouter(tags=["root"])


@router.get("/", response_model=RootResponse)
async def root() -> RootResponse:
    return RootResponse(message="API playground is running")
