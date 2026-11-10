import logging
import time
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from sqlalchemy import and_, delete, or_, select, update
from sqlalchemy.exc import SQLAlchemyError

from .astrology import ChartError, calculate
from .config import settings
from .db import RateLimit, Reading, Session, Visit

log = logging.getLogger(__name__)
MAX_ATTEMPTS = 2


def claim():
    now = datetime.now(UTC)
    with Session.begin() as db:
        job = db.scalar(select(Reading).where(
            Reading.expires_at > now,
            or_(
                and_(Reading.status == "queued", Reading.available_at <= now),
                and_(Reading.status == "running", Reading.lease_until < now),
            ),
        ).order_by(Reading.available_at).limit(1).with_for_update(skip_locked=True))
        if job is None:
            return None
        if job.attempts >= MAX_ATTEMPTS:
            job.status, job.error, job.input = "failed", "calculation_unavailable", None
            job.lease_id, job.lease_until = None, None
            return None
        job.attempts += 1
        job.status = "running"
        job.lease_id = uuid4().hex
        job.lease_until = now + timedelta(seconds=90)
        return job.token_hash, job.lease_id, job.attempts, job.input


def run_one() -> bool:
    job = claim()
    if job is None:
        return False
    key, lease, attempts, inputs = job
    result = None
    error = None
    retry = False
    try:
        result = calculate(inputs)
    except ChartError as exc:
        error, retry = exc.code, exc.retryable and attempts < MAX_ATTEMPTS
    except Exception as exc:
        log.error("Unexpected calculation failure: %s", type(exc).__name__)
        error = "calculation_unavailable"
    now = datetime.now(UTC)
    with Session.begin() as db:
        # A restarted worker may have taken over an expired lease.
        db.execute(update(Reading).where(Reading.token_hash == key, Reading.lease_id == lease).values(
            status="queued" if retry else "failed" if error else "ready",
            result=result, error=None if retry else error, input=inputs if retry else None,
            available_at=now + timedelta(seconds=4), lease_id=None, lease_until=None,
        ))
    return True


def cleanup():
    now = datetime.now(UTC)
    with Session.begin() as db:
        db.execute(delete(Reading).where(Reading.expires_at <= now))
        db.execute(delete(RateLimit).where(RateLimit.expires_at <= now))
        db.execute(delete(Visit).where(Visit.visited_at <= now - timedelta(days=30)))


def main():
    logging.basicConfig(level=logging.INFO)
    if not settings.can_calculate:
        raise SystemExit("Configure FATE_ROXY_API_KEY and FATE_IP_HASH_KEY before running the worker.")
    next_cleanup = 0
    while True:
        try:
            if time.monotonic() >= next_cleanup:
                cleanup()
                next_cleanup = time.monotonic() + 300
            if not run_one():
                time.sleep(0.6)
        except SQLAlchemyError as exc:
            log.error("Database unavailable: %s", type(exc).__name__)
            time.sleep(3)


if __name__ == "__main__":
    main()
