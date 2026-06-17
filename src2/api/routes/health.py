from fastapi import APIRouter

from src.schemas.health import HealthResponse

router = APIRouter(prefix="/health", tags=["health"])


@router.get("/", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    return HealthResponse(status="ok")


@router.get("/liveness", response_model=HealthResponse)
async def liveness() -> HealthResponse:
    return HealthResponse(status="alive")


@router.get("/readiness", response_model=HealthResponse)
async def readiness() -> HealthResponse:
    return HealthResponse(status="ready")
