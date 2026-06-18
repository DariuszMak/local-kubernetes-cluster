from typing import TYPE_CHECKING

from apps.auth_app.service import AuthService
from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import serializers, status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

if TYPE_CHECKING:
    from rest_framework.request import Request


class LoginView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(
        request=inline_serializer("LoginRequest", {"username": serializers.CharField()}),
        responses={
            200: inline_serializer(
                "LoginResponse", {"access_token": serializers.CharField(), "token_type": serializers.CharField()}
            )
        },
    )
    def post(self, request: Request) -> Response:

        username = request.data.get("username")
        if not username:
            return Response(
                {"detail": "username (email) is required"},
                status=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )

        service = AuthService()
        token = service.create_token_for_user(username)
        return Response({"access_token": token, "token_type": "bearer"})
