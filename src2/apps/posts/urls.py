from django.urls import path

from apps.posts.views import PostDetailView, PostListCreateView

urlpatterns = [
    path("", PostListCreateView.as_view()),
    path("<int:post_id>", PostDetailView.as_view()),
]
