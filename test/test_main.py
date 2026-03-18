import logging
import os
from pathlib import Path

import pytest

from src.main import load_dev_env


@pytest.fixture()
def tmp_env_file(tmp_path: Path) -> Path:
    env_file = tmp_path / "test.env"
    env_file.write_text(
        "EXAMPLE_VARIABLE_NAME=Hi it is me!\n"
        "# This is a comment\n"
        "ANOTHER_VAR=hello\n"
        "\n"  # blank line
        "  SPACED_VAR=spaced  \n",
        encoding="utf-8",
    )
    return env_file


def test_loads_variables(tmp_env_file: Path) -> None:
    for key in ("EXAMPLE_VARIABLE_NAME", "ANOTHER_VAR", "SPACED_VAR"):
        os.environ.pop(key, None)

    loaded = load_dev_env(str(tmp_env_file))

    assert loaded["EXAMPLE_VARIABLE_NAME"] == "Hi it is me!"
    assert loaded["ANOTHER_VAR"] == "hello"
    assert loaded["SPACED_VAR"] == "spaced"
    assert os.getenv("EXAMPLE_VARIABLE_NAME") == "Hi it is me!"


def test_skips_comments_and_blank_lines(tmp_env_file: Path) -> None:
    loaded = load_dev_env(str(tmp_env_file))
    assert all(not k.startswith("#") for k in loaded)


def test_does_not_override_existing_env_var(tmp_env_file: Path) -> None:
    os.environ["ANOTHER_VAR"] = "original"
    load_dev_env(str(tmp_env_file))
    assert os.getenv("ANOTHER_VAR") == "original"
    os.environ.pop("ANOTHER_VAR", None)


def test_missing_file_returns_empty() -> None:
    loaded = load_dev_env("nonexistent.env")
    assert loaded == {}


def test_dev_env_file_loads_example_variable() -> None:
    """Integration test: loads the actual dev.env from the project root."""
    os.environ.pop("EXAMPLE_VARIABLE_NAME", None)
    load_dev_env("dev.env")
    assert os.getenv("EXAMPLE_VARIABLE_NAME") == "Hi it is me!"


# --- logging tests ---

def test_logs_debug_for_loaded_var(tmp_env_file: Path, caplog: pytest.LogCaptureFixture) -> None:
    for key in ("EXAMPLE_VARIABLE_NAME", "ANOTHER_VAR", "SPACED_VAR"):
        os.environ.pop(key, None)

    with caplog.at_level(logging.DEBUG, logger="src.main"):
        load_dev_env(str(tmp_env_file))

    assert any("Loaded env var: EXAMPLE_VARIABLE_NAME" in m for m in caplog.messages)
    assert any("Loaded env var: ANOTHER_VAR" in m for m in caplog.messages)


def test_logs_debug_for_skipped_var(tmp_env_file: Path, caplog: pytest.LogCaptureFixture) -> None:
    os.environ["ANOTHER_VAR"] = "original"

    with caplog.at_level(logging.DEBUG, logger="src.main"):
        load_dev_env(str(tmp_env_file))

    assert any("Skipped env var (already set): ANOTHER_VAR" in m for m in caplog.messages)
    os.environ.pop("ANOTHER_VAR", None)


def test_logs_info_summary(tmp_env_file: Path, caplog: pytest.LogCaptureFixture) -> None:
    for key in ("EXAMPLE_VARIABLE_NAME", "ANOTHER_VAR", "SPACED_VAR"):
        os.environ.pop(key, None)

    with caplog.at_level(logging.INFO, logger="src.main"):
        load_dev_env(str(tmp_env_file))

    assert any("Loaded 3 var(s) from" in m for m in caplog.messages)


def test_logs_warning_for_missing_file(caplog: pytest.LogCaptureFixture) -> None:
    with caplog.at_level(logging.WARNING, logger="src.main"):
        load_dev_env("nonexistent.env")

    assert any("Env file not found: nonexistent.env" in m for m in caplog.messages)