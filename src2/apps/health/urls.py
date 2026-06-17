from django.urls import path

from apps.health.views import HealthCheckView, LivenessView, ReadinessView

urlpatterns = [
    path("", HealthCheckView.as_view()),
    path("liveness", LivenessView.as_view()),
    path("readiness", ReadinessView.as_view()),
]
