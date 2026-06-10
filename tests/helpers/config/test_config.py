
from src.helpers.config.config import Config


def test_config_defaults() -> None:
    config = Config()

    assert config.log_file == "app.log"
