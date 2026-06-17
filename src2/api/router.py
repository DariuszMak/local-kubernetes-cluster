from fastapi import APIRouter

from src2.api.routes import auth, health, posts, root, users

api_router = APIRouter()

api_router.include_router(root.router)
api_router.include_router(health.router)
api_router.include_router(users.router)
api_router.include_router(auth.router)
api_router.include_router(posts.router)
