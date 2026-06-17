from typing import TYPE_CHECKING

import pytest
import pytest_asyncio
from fastapi.testclient import TestClient

from src.db.base import Base
from src.db.session import get_db
from src.main import app
from tests.utils.db_config import TestingSessionLocal, engine

if TYPE_CHECKING:
    from collections.abc import AsyncGenerator, Generator

    from sqlalchemy.ext.asyncio import (
        AsyncSession,
    )


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


async def reset_db() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)


@pytest_asyncio.fixture(scope="session", autouse=True)
async def prepare_database() -> AsyncGenerator[None]:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession]:
    async with TestingSessionLocal() as session:
        yield session


@pytest.fixture(autouse=True)
def override_get_db(
    db_session: AsyncSession,
) -> Generator[None]:
    app.dependency_overrides[get_db] = lambda: db_session
    yield
    app.dependency_overrides.clear()
