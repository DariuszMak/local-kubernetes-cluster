from datetime import timedelta

from rest_framework_simplejwt.tokens import AccessToken


class AuthService:
    def create_token_for_user(self, email: str) -> str:
        token = AccessToken()
        token.set_exp(lifetime=timedelta(minutes=60))
        token["sub"] = email
        return str(token)
