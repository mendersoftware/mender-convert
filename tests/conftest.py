import os
import pytest
import sys

sys.path.append(
    os.path.join(os.path.dirname(__file__), "mender-image-tests", "tests")
)

# Load the parser for our custom option flags
pytest_plugins = "utils.parseropts.parseropts"
