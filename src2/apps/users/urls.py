from django.urls import path

from apps.users.views import CreateUserView, GetUserView

urlpatterns = [
    path("", CreateUserView.as_view()),
    path("<int:user_id>", GetUserView.as_view()),
]
