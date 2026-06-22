import os
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine




DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://postgres:postgres@localhost:5432/app"
)



engine = create_async_engine(
    DATABASE_URL,
    echo=False,  
)


async_session_maker = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)



async def get_db() -> AsyncGenerator[AsyncSession, None]:

    async with async_session_maker() as session:
        yield session