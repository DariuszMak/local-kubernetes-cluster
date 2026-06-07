from datetime import timedelta

from src.core.security import create_access_token


class AuthService:
    def create_token_for_user(self, email: str) -> str:
        return create_access_token(
            subject=email,
            expires_delta=timedelta(minutes=60),
        )
