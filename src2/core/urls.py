from apps.health.views import RootView
from django.urls import include, path
from drf_spectacular.renderers import OpenApiJsonRenderer
from drf_spectacular.views import SpectacularJSONAPIView, SpectacularRedocView, SpectacularSwaggerView


class PlainJsonRenderer(OpenApiJsonRenderer):
    media_type = "application/json"


class PlainJSONSchemaView(SpectacularJSONAPIView):
    renderer_classes = [PlainJsonRenderer]


urlpatterns = [
    path("", RootView.as_view()),
    path("health/", include("apps.health.urls")),
    path("users/", include("apps.users.urls")),
    path("auth/", include("apps.auth_app.urls")),
    path("users/<int:user_id>/posts/", include("apps.posts.urls")),
    path("openapi.json", PlainJSONSchemaView.as_view(), name="schema"),
    path("docs", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
    path("redoc", SpectacularRedocView.as_view(url_name="schema"), name="redoc"),
]
