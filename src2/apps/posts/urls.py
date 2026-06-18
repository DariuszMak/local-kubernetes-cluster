from apps.posts.views import PostDetailView, PostListCreateView
from django.urls import path

urlpatterns = [
    path("", PostListCreateView.as_view()),
    path("<int:post_id>", PostDetailView.as_view()),
]
