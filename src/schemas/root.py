from pydantic import BaseModel


class RootResponse(BaseModel):
    message: str

    model_config = {"json_schema_extra": {"example": {"message": "API playground is running"}}}
