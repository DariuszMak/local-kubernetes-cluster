from typing import TYPE_CHECKING

from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import serializers
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

if TYPE_CHECKING:
    from rest_framework.request import Request


class RootView(APIView):
    permission_classes = [AllowAny]

    def get(self, request: Request) -> Response:  # noqa: ARG002
        return Response({"message": "API playground is running"})


class HealthCheckView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(responses={200: inline_serializer("HealthResponse", {"status": serializers.CharField()})})
    def get(self, request: Request) -> Response:  # noqa: ARG002
        return Response({"status": "ok"})


class LivenessView(APIView):
    permission_classes = [AllowAny]

    def get(self, request: Request) -> Response:  # noqa: ARG002
        return Response({"status": "alive"})


class ReadinessView(APIView):
    permission_classes = [AllowAny]

    def get(self, request: Request) -> Response:  # noqa: ARG002
        return Response({"status": "ready"})
