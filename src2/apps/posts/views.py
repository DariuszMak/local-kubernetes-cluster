from typing import TYPE_CHECKING

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.posts.serializers import PostCreateSerializer, PostReadSerializer
from apps.posts.service import PostNotFoundError, PostService

if TYPE_CHECKING:
    from rest_framework.request import Request


class PostListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request: Request, user_id: int) -> Response:  # noqa: ARG002
        service = PostService()
        posts = service.get_posts_for_user(user_id)
        return Response(PostReadSerializer(posts, many=True).data)

    def post(self, request: Request, user_id: int) -> Response:
        serializer = PostCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_422_UNPROCESSABLE_ENTITY)

        service = PostService()
        post = service.create_post(
            user_id=user_id,
            title=serializer.validated_data["title"],
            body=serializer.validated_data.get("body", ""),
        )
        return Response(PostReadSerializer(post).data, status=status.HTTP_200_OK)


class PostDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request: Request, user_id: int, post_id: int) -> Response:  # noqa: ARG002
        service = PostService()
        try:
            post = service.get_post(post_id)
        except PostNotFoundError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_404_NOT_FOUND)
        return Response(PostReadSerializer(post).data)

    def delete(self, request: Request, user_id: int, post_id: int) -> Response:  # noqa: ARG002
        service = PostService()
        try:
            service.delete_post(post_id)
        except PostNotFoundError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_404_NOT_FOUND)
        return Response(status=status.HTTP_204_NO_CONTENT)
