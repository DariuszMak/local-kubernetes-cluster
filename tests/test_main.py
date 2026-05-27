import logging
import os
from typing import TYPE_CHECKING

import pytest

from src.main import load_dev_env, load_secrets

if TYPE_CHECKING:
    from pathlib import Path


# ── load_dev_env tests (unchanged behaviour) ────────────────────────────────

@pytest.fixture()
def tmp_env_file(tmp_path: Path) -> Path:
    env_file = tmp_path / "test.env"
    env_file.write_text(
        "EXAMPLE_VARIABLE_NAME=Hi it is me!\n# This is a comment\nANOTHER_VAR=hello\n\n  SPACED_VAR=spaced  \n",
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
    loaded = load_dev_env(".nonexistent.env")
    assert loaded == {}


def test_dev_env_file_loads_example_variable() -> None:
    """Integration test: loads the actual .dev.env from the project root."""
    os.environ.pop("EXAMPLE_VARIABLE_NAME", None)
    load_dev_env(".dev.env")
    assert os.getenv("EXAMPLE_VARIABLE_NAME") == "Hi it is me!"


def test_logs_debug_for_loaded_var(tmp_env_file: Path, caplog: pytest.LogCaptureFixture) -> None:
    for key in ("EXAMPLE_VARIABLE_NAME", "ANOTHER_VAR", "SPACED_VAR"):
        os.environ.pop(key, None)

    with caplog.at_level(logging.DEBUG, logger="src.main"):
        load_dev_env(str(tmp_env_file))

    assert any("Loaded env var: EXAMPLE_VARIABLE_NAME=" in m for m in caplog.messages)
    assert any("Loaded env var: ANOTHER_VAR=" in m for m in caplog.messages)


def test_logs_debug_for_skipped_var(tmp_env_file: Path, caplog: pytest.LogCaptureFixture) -> None:
    os.environ["ANOTHER_VAR"] = "original"

    with caplog.at_level(logging.DEBUG, logger="src.main"):
        load_dev_env(str(tmp_env_file))

    assert any("Skipped env var (already set): ANOTHER_VAR=" in m for m in caplog.messages)
    os.environ.pop("ANOTHER_VAR", None)


def test_logs_info_summary(tmp_env_file: Path, caplog: pytest.LogCaptureFixture) -> None:
    for key in ("EXAMPLE_VARIABLE_NAME", "ANOTHER_VAR", "SPACED_VAR"):
        os.environ.pop(key, None)

    with caplog.at_level(logging.INFO, logger="src.main"):
        load_dev_env(str(tmp_env_file))

    assert any("Loaded 3 var(s) from" in m for m in caplog.messages)


def test_logs_warning_for_missing_file(caplog: pytest.LogCaptureFixture) -> None:
    with caplog.at_level(logging.WARNING, logger="src.main"):
        load_dev_env(".nonexistent.env")

    assert any("Env file not found: .nonexistent.env" in m for m in caplog.messages)


# ── load_secrets() priority tests ───────────────────────────────────────────

@pytest.fixture(autouse=True)
def _clean_vault_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """Ensure Vault-related env vars are clean before each test."""
    monkeypatch.delenv("VAULT_SECRETS_FILE", raising=False)
    monkeypatch.delenv("EXAMPLE_VARIABLE_NAME", raising=False)


def test_load_secrets_uses_vault_secrets_file_when_set(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """VAULT_SECRETS_FILE takes priority over everything else."""
    vault_file = tmp_path / "app.env"
    vault_file.write_text("EXAMPLE_VARIABLE_NAME=from-vault\n", encoding="utf-8")
    monkeypatch.setenv("VAULT_SECRETS_FILE", str(vault_file))

    load_secrets()

    assert os.getenv("EXAMPLE_VARIABLE_NAME") == "from-vault"


def test_load_secrets_uses_local_vault_env_when_no_vault_file(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, tmp_cwd: Path
) -> None:
    """Falls back to .vault-secrets.env when VAULT_SECRETS_FILE is not set."""
    local_vault = tmp_cwd / ".vault-secrets.env"
    local_vault.write_text("EXAMPLE_VARIABLE_NAME=from-local-vault\n", encoding="utf-8")

    load_secrets()

    assert os.getenv("EXAMPLE_VARIABLE_NAME") == "from-local-vault"


def test_load_secrets_falls_back_to_dev_env(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Falls back to .dev.env when neither Vault source is available."""
    monkeypatch.delenv("VAULT_SECRETS_FILE", raising=False)
    # Ensure .vault-secrets.env does not exist in cwd (it shouldn't in CI)
    if os.path.exists(".vault-secrets.env"):
        pytest.skip(".vault-secrets.env present in cwd — skipping fallback test")

    load_secrets()

    # .dev.env sets EXAMPLE_VARIABLE_NAME=Hi it is me!
    assert os.getenv("EXAMPLE_VARIABLE_NAME") == "Hi it is me!"


def test_load_secrets_vault_file_missing_path_falls_through(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """VAULT_SECRETS_FILE set but file missing — should fall through gracefully."""
    monkeypatch.setenv("VAULT_SECRETS_FILE", "/nonexistent/path/app.env")
    if os.path.exists(".vault-secrets.env"):
        pytest.skip(".vault-secrets.env present — skipping")

    load_secrets()  # should not raise

    assert os.getenv("EXAMPLE_VARIABLE_NAME") == "Hi it is me!"


# ── conftest helper ─────────────────────────────────────────────────────────

@pytest.fixture()
def tmp_cwd(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """Change the working directory to a temp path for the duration of a test."""
    monkeypatch.chdir(tmp_path)
    return tmp_path
