from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING, Any

from drf_spectacular.extensions import OpenApiAuthenticationExtension
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import AccessToken

if TYPE_CHECKING:
    from drf_spectacular.openapi import AutoSchema
    from rest_framework.request import Request


class EmailJWTAuthentication(JWTAuthentication):
    def authenticate(self, request: Request) -> tuple[_TokenUser, AccessToken] | None:  # type: ignore[override]
        header = self.get_header(request)
        if header is None:
            return None

        raw_token = self.get_raw_token(header)
        if raw_token is None:
            return None

        try:
            validated_token = AccessToken(raw_token)  # type: ignore[arg-type]
        except TokenError as e:
            raise InvalidToken(e.args[0]) from e

        email = validated_token.get("sub")
        if not email:
            raise InvalidToken("Token has no 'sub' claim")

        return _TokenUser(email), validated_token


class EmailJWTAuthenticationScheme(OpenApiAuthenticationExtension):  # type: ignore[no-untyped-call]
    target_class = "core.authentication.EmailJWTAuthentication"
    name = "bearerAuth"

    def get_security_definition(self, _auto_schema: AutoSchema) -> dict[str, Any]:
        return {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
        }


@dataclass
class _TokenUser:
    email: str
    is_authenticated: bool = True
