import pytest

from backend.tests.postgres_fixture import isolated_database


@pytest.fixture
def postgres_url(request):
    with isolated_database(getattr(request, "param", "head")) as url:
        yield url
