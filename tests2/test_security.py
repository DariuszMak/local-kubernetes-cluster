from typing import Any, cast

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import AccessToken

from apps.auth_app.service import AuthService


def _decode_token(token: str) -> str:
    validated = AccessToken(cast("Any", token))
    email = validated.get("sub")
    assert email is not None
    return str(email)


def test_token_roundtrip() -> None:
    service = AuthService()

    token = service.create_token_for_user("test@example.com")
    subject = _decode_token(token)

    assert subject == "test@example.com"


def test_token_type_is_string() -> None:
    service = AuthService()

    token = service.create_token_for_user("any@example.com")

    assert isinstance(token, str)
    assert token  # non-empty


def test_invalid_token_raises() -> None:

    with pytest.raises(TokenError, match="Token is invalid"):
        _decode_token("not.a.valid.token")


@settings(deadline=None, max_examples=50)
@given(email=st.emails())
def test_token_property(email: str) -> None:
    service = AuthService()

    token = service.create_token_for_user(email)

    assert _decode_token(token) == email


@settings(deadline=None, max_examples=20)
@given(email=st.emails())
def test_two_tokens_for_same_email_both_valid(email: str) -> None:
    service = AuthService()

    token_a = service.create_token_for_user(email)
    token_b = service.create_token_for_user(email)

    assert _decode_token(token_a) == email
    assert _decode_token(token_b) == email
