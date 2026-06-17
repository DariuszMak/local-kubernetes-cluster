from apps.posts.models import Post


class PostRepository:
    def get_by_id(self, post_id: int) -> Post | None:
        try:
            return Post.objects.get(pk=post_id)
        except Post.DoesNotExist:
            return None

    def get_by_user_id(self, user_id: int) -> list[Post]:
        return list(Post.objects.filter(user_id=user_id))

    def create(self, user_id: int, title: str, body: str = "") -> Post:
        return Post.objects.create(user_id=user_id, title=title, body=body)

    def delete(self, post: Post) -> None:
        post.delete()
