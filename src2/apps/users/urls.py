from apps.users.views import CreateUserView, GetUserView
from django.urls import path

urlpatterns = [
    path("", CreateUserView.as_view()),
    path("<int:user_id>", GetUserView.as_view()),
]
