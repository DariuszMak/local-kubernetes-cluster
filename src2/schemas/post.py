from pydantic import BaseModel, ConfigDict


class PostCreate(BaseModel):
    title: str
    body: str = ""


class PostRead(BaseModel):
    id: int
    title: str
    body: str
    user_id: int

    model_config = ConfigDict(from_attributes=True)
