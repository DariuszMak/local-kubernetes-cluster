import logging
from collections.abc import Generator
from pathlib import Path
from typing import Any

import pytest
import structlog

from src.helpers.logging_setup import logging_setup


@pytest.fixture(autouse=True)
def reset_logging() -> Generator[None]:
    logger = logging.getLogger()
    logger.handlers.clear()
    yield
    logger.handlers.clear()


def _get_file_handlers(logger: logging.Logger) -> list[logging.FileHandler]:
    return [h for h in logger.handlers if isinstance(h, logging.FileHandler)]


def _get_stream_handlers(logger: logging.Logger) -> list[logging.StreamHandler[Any]]:
    return [
        h
        for h in logger.handlers
        if isinstance(h, logging.StreamHandler)
        and not isinstance(h, logging.FileHandler)
        and h.__class__ is logging.StreamHandler
    ]


def test_logging_setup_adds_handlers(tmp_path: Path) -> None:
    log_file = tmp_path / "test.log"

    logging_setup(log_file=str(log_file))

    logger = logging.getLogger()

    assert any(isinstance(h, logging.FileHandler) for h in logger.handlers)
    assert any(isinstance(h, logging.StreamHandler) and not isinstance(h, logging.FileHandler) for h in logger.handlers)


def test_logging_writes_to_file(tmp_path: Path) -> None:
    log_file = tmp_path / "test.log"

    logging_setup(log_file=str(log_file))

    logger = structlog.get_logger()
    logger.info("test message", test_key="value")

    root_logger = logging.getLogger()

    for handler in _get_file_handlers(root_logger):
        handler.flush()

    with open(log_file) as f:
        content = f.read()

    assert "test message" in content
    assert "test_key" in content


def test_logging_level(tmp_path: Path) -> None:
    log_file = tmp_path / "test.log"

    logging_setup(level=logging.DEBUG, log_file=str(log_file))

    logger = logging.getLogger()

    assert logger.level == logging.DEBUG


def test_formatter_is_set(tmp_path: Path) -> None:
    log_file = tmp_path / "test.log"

    logging_setup(log_file=str(log_file))

    logger = logging.getLogger()

    for handler in logger.handlers:
        if isinstance(handler, (logging.FileHandler, logging.StreamHandler)):
            assert handler.formatter is not None


def test_no_duplicate_handlers(tmp_path: Path) -> None:
    log_file = tmp_path / "test.log"

    logging_setup(log_file=str(log_file))
    logging_setup(log_file=str(log_file))

    logger = logging.getLogger()

    file_handlers = _get_file_handlers(logger)
    stream_handlers = _get_stream_handlers(logger)

    assert len(file_handlers) == 1
    assert len(stream_handlers) == 1
