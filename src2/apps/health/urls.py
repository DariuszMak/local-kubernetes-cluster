from apps.health.views import HealthCheckView, LivenessView, ReadinessView
from django.urls import path

urlpatterns = [
    path("", HealthCheckView.as_view()),
    path("liveness", LivenessView.as_view()),
    path("readiness", ReadinessView.as_view()),
]
