import pytest

from backend.tests.postgres_fixture import isolated_database


@pytest.fixture
def postgres_url():
    with isolated_database() as url:
        yield url
