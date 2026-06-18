from apps.auth_app.views import LoginView
from django.urls import path

urlpatterns = [
    path("login", LoginView.as_view()),
]
