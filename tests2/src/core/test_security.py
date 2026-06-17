from hypothesis import given, settings
from hypothesis import strategies as st

from src2.helpers.security import create_access_token, decode_access_token


def test_token_roundtrip() -> None:
    token = create_access_token("test@example.com")

    subject = decode_access_token(token)

    assert subject == "test@example.com"


@settings(deadline=None)
@given(email=st.emails())
def test_token_property(email: str) -> None:
    token = create_access_token(email)

    assert decode_access_token(token) == email
