from typing import TYPE_CHECKING

from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.users.serializers import UserReadSerializer
from apps.users.service import UserNotFoundError, UserService
from core.exceptions import DuplicateEmailError

if TYPE_CHECKING:
    from rest_framework.request import Request


class CreateUserView(APIView):
    permission_classes = [AllowAny]

    def post(self, request: Request) -> Response:
        email = request.query_params.get("email") or request.data.get("email")
        if not email:
            return Response({"detail": "email is required"}, status=status.HTTP_422_UNPROCESSABLE_ENTITY)

        service = UserService()
        try:
            user = service.create_user(email)
        except DuplicateEmailError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        return Response(UserReadSerializer(user).data, status=status.HTTP_200_OK)


class GetUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request: Request, user_id: int) -> Response:  # noqa: ARG002
        service = UserService()
        try:
            user = service.get_user(user_id)
        except UserNotFoundError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_404_NOT_FOUND)

        return Response(UserReadSerializer(user).data)
