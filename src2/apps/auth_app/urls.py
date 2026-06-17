from django.urls import path

from apps.auth_app.views import LoginView

urlpatterns = [
    path("login", LoginView.as_view()),
]
