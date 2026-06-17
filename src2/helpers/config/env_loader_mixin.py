import os
from dataclasses import MISSING, fields
from typing import Any, Protocol, cast


class DataclassInstance(Protocol):
    __dataclass_fields__: dict[str, Any]


class EnvLoaderMixin:
    def __post_init__(self) -> None:
        for field in fields(cast("Any", self)):
            env_name = field.name.upper()
            raw_value = os.getenv(env_name)

            if raw_value is None:
                continue

            current_value = getattr(self, field.name)

            if field.default is not MISSING:
                default_value = field.default
            elif field.default_factory is not MISSING:
                default_value = field.default_factory()
            else:
                continue

            if current_value != default_value:
                continue

            value: Any
            if field.type is int:
                value = int(raw_value)
            elif field.type is bool:
                value = raw_value.lower() in {"1", "true", "yes"}
            else:
                value = raw_value

            object.__setattr__(self, field.name, value)
