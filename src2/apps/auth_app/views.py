from typing import TYPE_CHECKING

from apps.auth_app.service import AuthService
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

if TYPE_CHECKING:
    from rest_framework.request import Request


class LoginView(APIView):
    permission_classes = [AllowAny]

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
