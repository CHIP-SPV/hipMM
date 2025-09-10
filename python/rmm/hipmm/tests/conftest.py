import pytest

def pytest_configure(config):
    """
    Set pytest import mode to 'importlib' to address import issues with hipmm and its submodules.
    This ensures that tests and modules are imported in a way that avoids conflicts or errors
    specific to the hipmm package structure.
    """
    config.option.importmode = "importlib"
