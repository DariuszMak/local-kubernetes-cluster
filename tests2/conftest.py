import pytest
from django.test import Client


@pytest.fixture
def client() -> Client:
    return Client()


@pytest.fixture(autouse=True)
def reset_db(db: None) -> None:
    _ = db
