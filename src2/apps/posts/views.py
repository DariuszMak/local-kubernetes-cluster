from typing import TYPE_CHECKING

from apps.posts.serializers import PostCreateSerializer, PostReadSerializer
from apps.posts.service import PostNotFoundError, PostService
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

if TYPE_CHECKING:
    from rest_framework.request import Request


class PostListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="list_user_posts",
        responses={200: PostReadSerializer(many=True)},
        summary="List all posts for a specific user",
    )
    def get(self, request: Request, user_id: int) -> Response:  # noqa: ARG002
        service = PostService()
        posts = service.get_posts_for_user(user_id)
        return Response(PostReadSerializer(posts, many=True).data)

    @extend_schema(
        operation_id="create_user_post",
        request=PostCreateSerializer,
        responses={200: PostReadSerializer},
        summary="Create a new post for a specific user",
    )
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

    @extend_schema(
        operation_id="retrieve_user_post_detail",
        responses={200: PostReadSerializer, 404: dict},
        summary="Get a specific post detail",
    )
    def get(self, request: Request, user_id: int, post_id: int) -> Response:  # noqa: ARG002
        service = PostService()
        try:
            post = service.get_post(post_id)
        except PostNotFoundError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_404_NOT_FOUND)
        return Response(PostReadSerializer(post).data)

    @extend_schema(
        operation_id="delete_user_post",
        responses={204: None, 404: dict},
        summary="Delete a specific post",
    )
    def delete(self, request: Request, user_id: int, post_id: int) -> Response:  # noqa: ARG002
        service = PostService()
        try:
            service.delete_post(post_id)
        except PostNotFoundError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_404_NOT_FOUND)
        return Response(status=status.HTTP_204_NO_CONTENT)
