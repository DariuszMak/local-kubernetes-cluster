from datetime import UTC, datetime, timedelta
from typing import Any

from jose import JWTError, jwt
from passlib.context import CryptContext

from src.helpers.config import get_settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

ALGORITHM = "HS256"


def create_access_token(subject: str, expires_delta: timedelta | None = None) -> str:
    settings = get_settings()
    expire = datetime.now(UTC) + (expires_delta or timedelta(minutes=30))

    to_encode: dict[str, Any] = {
        "sub": subject,
        "exp": expire,
    }

    return jwt.encode(to_encode, settings.app_name, algorithm=ALGORITHM)


def decode_access_token(token: str) -> str:
    settings = get_settings()

    try:
        payload = jwt.decode(token, settings.app_name, algorithms=[ALGORITHM])
        subject: str | None = payload.get("sub")

        if subject is None:
            raise ValueError("Missing subject")
        else:
            return subject

    except JWTError as exc:
        raise ValueError("Invalid token") from exc
