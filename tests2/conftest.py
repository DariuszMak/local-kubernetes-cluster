import pytest
from django.test import Client


@pytest.fixture
def client() -> Client:
    return Client()


@pytest.fixture(autouse=True)
def reset_db(db: None) -> None:
    _ = db


@pytest.fixture(autouse=True)
def disable_throttling(settings):

    settings.REST_FRAMEWORK = {
        **settings.REST_FRAMEWORK,
        "DEFAULT_THROTTLE_CLASSES": [],
    }

    settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"] = {
        "anon": None,
        "user": None,
    }
