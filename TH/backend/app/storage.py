import hashlib
import hmac
import json
import secrets
import time
from contextlib import contextmanager
from uuid import uuid4

import psycopg
from psycopg.conninfo import conninfo_to_dict
from psycopg.rows import dict_row

from .accounts import (
    DUMMY_PASSWORD_HASH, H5_LOGIN_RETENTION_AFTER_EXPIRY, H5_LOGIN_SECONDS,
    new_h5_login_code, password_hash, password_matches,
)


class Storage:
    def __init__(self, database_url: str):
        if not database_url.startswith(("postgresql://", "postgres://")):
            raise RuntimeError("DATABASE_URL must point to the FATE PostgreSQL database.")
        self._database_url = database_url
        self.database_name = conninfo_to_dict(database_url).get("dbname") or "PostgreSQL"

    @contextmanager
    def connect(self):
        with psycopg.connect(self._database_url, row_factory=dict_row, connect_timeout=5) as db:
            db.execute("SET LOCAL lock_timeout = '5s'")
            yield db

    def verify_schema(self):
        try:
            with self.connect() as db:
                version = db.execute("SELECT version_num FROM alembic_version").fetchone()
        except psycopg.Error:
            raise RuntimeError("PostgreSQL is unavailable or the FATE schema has not been installed.") from None
        if version is None or version["version_num"] != "20261126_merge_h5_integrity":
            raise RuntimeError("Apply the FATE PostgreSQL migrations before starting the backend.")

    def login(self, hours: int):
        user_id = str(uuid4())
        with self.connect() as db:
            db.execute("INSERT INTO users VALUES (%s, %s)", (user_id, time.time()))
            return self._create_session(db, user_id, hours)

    def _create_session(self, db, user_id: str, hours: int):
        token, now = secrets.token_urlsafe(32), time.time()
        db.execute("DELETE FROM sessions WHERE expires < %s", (now,))
        db.execute("INSERT INTO sessions VALUES (%s, %s, %s)", (self.hash(token), user_id, now + hours * 3600))
        return {"token": token, "user_id": user_id}

    def account(self, user_id: str):
        with self.connect() as db:
            return self._account(db, user_id)

    @staticmethod
    def _account(db, user_id: str):
        row = db.execute("SELECT username FROM accounts WHERE user_id=%s", (user_id,)).fetchone()
        linked = row is None and db.execute("SELECT 1 FROM h5_app_accounts WHERE user_id=%s", (user_id,)).fetchone()
        return {"user_id": user_id, "username": row["username"] if row else None,
                "kind": "account" if row else "h5" if linked else "guest"}

    def h5_report_owner(self, user_id: str):
        with self.connect() as db:
            row = db.execute("SELECT owner FROM h5_app_accounts WHERE user_id=%s", (user_id,)).fetchone()
        return row["owner"] if row else None

    @staticmethod
    def _h5_code_digest(key: str, code: str) -> str:
        return hmac.digest(key.encode(), code.encode(), "sha256").hex()

    def prune_h5_login_codes(self):
        cutoff = time.time() - H5_LOGIN_RETENTION_AFTER_EXPIRY
        with self.connect() as db:
            db.execute("SET LOCAL statement_timeout = '5s'")
            db.execute("DELETE FROM h5_app_login_codes WHERE expires<=%s", (cutoff,))

    def issue_h5_login_code(self, owner: str, report_id: str):
        with self.connect() as db:
            db.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s,20261118))", (owner,))
            now = time.time()
            key = db.execute("SELECT secret FROM h5_app_login_key WHERE id=1").fetchone()["secret"]
            for _ in range(6):
                code = new_h5_login_code()
                try:
                    with db.transaction():
                        db.execute("UPDATE h5_app_login_codes SET active=FALSE WHERE owner=%s AND active", (owner,))
                        db.execute(
                            "INSERT INTO h5_app_login_codes(owner,digest,expires,report_id) VALUES (%s,%s,%s,%s)",
                            (owner, self._h5_code_digest(key, code), now + H5_LOGIN_SECONDS, report_id),
                        )
                    return {"code": code, "expires_in": H5_LOGIN_SECONDS}
                except psycopg.errors.UniqueViolation:
                    continue
        return None

    def expired_h5_login_code(self, db, code: str, now: float):
        key = db.execute("SELECT secret FROM h5_app_login_key WHERE id=1").fetchone()["secret"]
        return db.execute(
            """SELECT owner,report_id FROM h5_app_login_codes
               WHERE digest=%s AND expires<=%s AND expires>%s""",
            (self._h5_code_digest(key, code.upper()), now, now - H5_LOGIN_RETENTION_AFTER_EXPIRY),
        ).fetchone()

    def redeem_h5_login_code(self, code: str, network: str, hours: int):
        with self.connect() as db:
            # Keep the shared failure budget and one-time redemption atomic across API workers.
            db.execute("SELECT pg_advisory_xact_lock(20261118, 6)")
            now = time.time()
            window = int(now // H5_LOGIN_SECONDS)
            failures = {row["scope"]: row["attempts"] for row in db.execute(
                "SELECT scope,attempts FROM h5_app_login_failures WHERE window_id=%s AND scope IN (%s,%s)",
                (window, "global", network),
            )}
            if failures.get("global", 0) >= 120 or failures.get(network, 0) >= 8:
                return "too_many_requests", None
            key = db.execute("SELECT secret FROM h5_app_login_key WHERE id=1").fetchone()["secret"]
            claim = db.execute(
                """UPDATE h5_app_login_codes SET active=FALSE
                   WHERE digest=%s AND active AND expires>%s RETURNING owner""",
                (self._h5_code_digest(key, code), now),
            ).fetchone()
            if claim is None:
                db.execute("DELETE FROM h5_app_login_failures WHERE window_id<%s", (window,))
                db.execute(
                    """INSERT INTO h5_app_login_failures(scope,window_id,attempts) VALUES (%s,%s,1),(%s,%s,1)
                       ON CONFLICT(scope) DO UPDATE SET attempts=h5_app_login_failures.attempts+1""",
                    ("global", window, network, window),
                )
                return "h5_login_code_invalid", None
            owner = claim["owner"]
            link = db.execute("SELECT user_id FROM h5_app_accounts WHERE owner=%s", (owner,)).fetchone()
            if link:
                user_id = link["user_id"]
            else:
                user_id = str(uuid4())
                db.execute("INSERT INTO users VALUES (%s, %s)", (user_id, now))
                db.execute("INSERT INTO h5_app_accounts VALUES (%s,%s)", (owner, user_id))
            session = self._create_session(db, user_id, hours)
            return None, {**session, "account": self._account(db, user_id)}

    def register(self, username: str, password: str, hours: int, existing_user: str | None = None):
        encoded = password_hash(password)
        user_id, token = str(uuid4()), secrets.token_urlsafe(32)
        with self.connect() as db:
            if existing_user:
                self._lock_user(db, existing_user)
            # A signed-in anonymous visitor may bind their existing profile to a new account.
            if existing_user and not db.execute("SELECT 1 FROM accounts WHERE user_id=%s", (existing_user,)).fetchone():
                user_id = existing_user
            else:
                db.execute("INSERT INTO users VALUES (%s, %s)", (user_id, time.time()))
            try:
                db.execute("INSERT INTO accounts VALUES (%s, %s, %s)", (user_id, username, encoded))
            except psycopg.errors.UniqueViolation:
                raise ValueError("account_exists") from None
            db.execute("DELETE FROM sessions WHERE user_id=%s", (user_id,))
            db.execute("INSERT INTO sessions VALUES (%s, %s, %s)", (self.hash(token), user_id, time.time() + hours * 3600))
        return {"token": token, "user_id": user_id}

    def account_login(self, username: str, password: str, hours: int):
        with self.connect() as db:
            row = db.execute("SELECT user_id, password_hash FROM accounts WHERE lower(username)=lower(%s)", (username,)).fetchone()
        matches = password_matches(password, row["password_hash"] if row else DUMMY_PASSWORD_HASH)
        if not row or not matches:
            return None
        token = secrets.token_urlsafe(32)
        with self.connect() as db:
            db.execute("DELETE FROM sessions WHERE expires < %s", (time.time(),))
            db.execute("INSERT INTO sessions VALUES (%s, %s, %s)", (self.hash(token), row["user_id"], time.time() + hours * 3600))
        return {"token": token, "user_id": row["user_id"]}

    @staticmethod
    def hash(token: str):
        return hashlib.sha256(token.encode()).hexdigest()

    def authenticate(self, token: str):
        with self.connect() as db:
            row = db.execute("SELECT user_id FROM sessions WHERE hash=%s AND expires>%s", (self.hash(token), time.time())).fetchone()
        return row["user_id"] if row else None

    def logout(self, token: str):
        with self.connect() as db:
            db.execute("DELETE FROM sessions WHERE hash=%s", (self.hash(token),))

    def profile(self, user_id: str):
        with self.connect() as db:
            row = db.execute("SELECT * FROM profiles WHERE user_id=%s", (user_id,)).fetchone()
            preference = db.execute("SELECT language FROM preferences WHERE user_id=%s", (user_id,)).fetchone()
        if not row:
            return None
        payload = json.loads(row["payload"])
        if preference:
            payload["language"] = preference["language"]
        return {"profile_id": "p_" + self.hash(user_id)[:24], "revision": row["revision"], "profile": payload, "chart": json.loads(row["chart"])}

    def set_language(self, user_id: str, language: str):
        with self.connect() as db:
            db.execute("INSERT INTO preferences VALUES (%s,%s) ON CONFLICT(user_id) DO UPDATE SET language=excluded.language", (user_id, language))
        return {"language": language}

    def companion(self, user_id: str):
        with self.connect() as db:
            row = db.execute("SELECT payload FROM companion WHERE user_id=%s", (user_id,)).fetchone()
        return json.loads(row["payload"]) if row else None

    def save_companion(self, user_id: str, payload: dict):
        with self.connect() as db:
            db.execute("INSERT INTO companion VALUES (%s,%s) ON CONFLICT(user_id) DO UPDATE SET payload=excluded.payload", (user_id, json.dumps(payload)))
        return payload

    def thai_chart(self, user_id: str, fingerprint: str):
        with self.connect() as db:
            row = db.execute("SELECT payload FROM thai_charts WHERE user_id=%s AND fingerprint=%s", (user_id, fingerprint)).fetchone()
        return json.loads(row["payload"]) if row else None

    def save_thai_chart(self, user_id: str, fingerprint: str, payload: dict):
        with self.connect() as db:
            db.execute("INSERT INTO thai_charts VALUES (%s,%s,%s) ON CONFLICT(user_id) DO UPDATE SET fingerprint=excluded.fingerprint,payload=excluded.payload", (user_id, fingerprint, json.dumps(payload)))
        return payload

    def save_profile(self, user_id: str, payload: dict, chart: dict, *, expected_revision="unchecked"):
        with self.connect() as db:
            self._lock_user(db, user_id)
            previous = db.execute("SELECT payload,revision FROM profiles WHERE user_id=%s", (user_id,)).fetchone()
            if expected_revision != "unchecked" and expected_revision != (previous["revision"] if previous else None):
                raise ValueError("profile_changed")
            birth_fields = ("birth_date", "birth_time", "timezone", "birthplace", "country_code", "location_id", "latitude", "longitude")
            old_profile = json.loads(previous["payload"]) if previous else {}
            birth_changed = any(old_profile.get(field) != payload.get(field) for field in birth_fields)
            db.execute(
                """INSERT INTO profiles VALUES (%s, 1, %s, %s) ON CONFLICT(user_id)
                DO UPDATE SET revision=profiles.revision+1, payload=excluded.payload, chart=excluded.chart""",
                (user_id, json.dumps(payload), json.dumps(chart)),
            )
            if birth_changed:
                db.execute("DELETE FROM messages WHERE user_id=%s", (user_id,))
        return self.profile(user_id)

    def history(self, user_id: str, limit: int = 60):
        with self.connect() as db:
            rows = db.execute(
                "SELECT m.id, m.role, m.content, m.provider, m.created, r.evidence FROM messages m LEFT JOIN chat_readings r ON r.message_id=m.id AND r.user_id=m.user_id WHERE m.user_id=%s ORDER BY m.seq DESC LIMIT %s", (user_id, limit)
            ).fetchall()
        return [{**{key: row[key] for key in ("id", "role", "content", "provider", "created")}, **({"evidence": json.loads(row["evidence"])} if row["evidence"] else {})} for row in reversed(rows)]

    def save_pair(self, user_id: str, question: str, answer: str, provider: str, evidence: dict | None = None):
        answer_id = str(uuid4())
        with self.connect() as db:
            self._lock_user(db, user_id)
            db.cursor().executemany(
                "INSERT INTO messages(id,user_id,role,content,provider,created) VALUES (%s,%s,%s,%s,%s,%s)",
                [(str(uuid4()), user_id, "user", question, provider, time.time()), (answer_id, user_id, "assistant", answer, provider, time.time())],
            )
            if evidence is not None:
                db.execute("INSERT INTO chat_readings VALUES (%s,%s,%s,%s,%s)", (answer_id, user_id, "User: " + question + "\n\nAssistant: " + answer, json.dumps(evidence), time.time()))
        return answer_id

    def clear_history(self, user_id: str):
        with self.connect() as db:
            self._lock_user(db, user_id)
            db.execute("DELETE FROM messages WHERE user_id=%s", (user_id,))

    def memories(self, user_id: str):
        with self.connect() as db:
            rows = db.execute("SELECT id, content, created FROM memories WHERE user_id=%s ORDER BY created", (user_id,)).fetchall()
        return [{**dict(row), "source": "user_confirmed"} for row in rows]

    def add_memory(self, user_id: str, content: str):
        memory_id = str(uuid4())
        with self.connect() as db:
            self._lock_user(db, user_id)
            count = db.execute("SELECT COUNT(*) AS count FROM memories WHERE user_id=%s", (user_id,)).fetchone()
            if count["count"] >= 20:
                raise ValueError("memory_limit")
            db.execute("INSERT INTO memories VALUES (%s,%s,%s,%s)", (memory_id, user_id, content, time.time()))
        return next(item for item in self.memories(user_id) if item["id"] == memory_id)

    def delete_memory(self, user_id: str, memory_id: str):
        with self.connect() as db:
            return db.execute("DELETE FROM memories WHERE user_id=%s AND id=%s", (user_id, memory_id)).rowcount > 0

    def update_memory(self, user_id: str, memory_id: str, content: str):
        with self.connect() as db:
            if not db.execute("UPDATE memories SET content=%s WHERE user_id=%s AND id=%s", (content, user_id, memory_id)).rowcount:
                return None
        return next(item for item in self.memories(user_id) if item["id"] == memory_id)

    def reserve_chat(self, user_id: str, per_minute: int, per_day: int):
        # Ported from Roxy's chat-limit.ts; count attempts to also bound failed paid calls.
        now = time.time()
        with self.connect() as db:
            self._lock_user(db, user_id)
            db.execute("DELETE FROM chat_usage WHERE created<%s", (now - 86400,))
            usage = db.execute("SELECT COUNT(*) FILTER (WHERE created>=%s) AS minute,COUNT(*) AS day "
                               "FROM chat_usage WHERE user_id=%s AND created>=%s", (now - 60, user_id, now - 86400)).fetchone()
            if usage["day"] >= per_day:
                return "chat_daily_limit"
            if usage["minute"] >= per_minute:
                return "chat_minute_limit"
            db.execute("INSERT INTO chat_usage VALUES (%s,%s,%s)", (str(uuid4()), user_id, now))
        return None

    def reserve_roxy(self, scopes: list[str], per_minute: int, per_day: int):
        now = time.time()
        scopes = list(set(scopes))
        with self.connect() as db:
            db.execute("LOCK TABLE roxy_usage IN SHARE ROW EXCLUSIVE MODE")
            db.execute("DELETE FROM roxy_usage WHERE created<%s", (now - 86400,))
            for scope in scopes:
                usage = db.execute("SELECT COUNT(*) FILTER (WHERE created>=%s) AS minute,COUNT(*) AS day "
                                   "FROM roxy_usage WHERE scope=%s AND created>=%s", (now - 60, scope, now - 86400)).fetchone()
                if usage["minute"] >= per_minute or usage["day"] >= per_day:
                    return False
            db.cursor().executemany("INSERT INTO roxy_usage VALUES (%s,%s)", [(scope, now) for scope in scopes])
        return True

    def recall_readings(self, user_id: str, signature: str):
        with self.connect() as db:
            rows = db.execute("SELECT r.message_id AS id,r.content,r.created,v.embedding FROM chat_readings r LEFT JOIN reading_vectors v ON v.message_id=r.message_id AND v.signature=%s WHERE r.user_id=%s ORDER BY r.created DESC LIMIT 200", (signature, user_id)).fetchall()
        return [dict(row) for row in rows]

    def reading(self, user_id: str, message_id: str):
        with self.connect() as db:
            row = db.execute("SELECT message_id AS id,content,created FROM chat_readings WHERE user_id=%s AND message_id=%s", (user_id, message_id)).fetchone()
        return dict(row) if row else None

    def index_reading(self, user_id: str, message_id: str, signature: str, vector: list):
        # The guarded SELECT prevents a delayed embedding resurrecting deleted history.
        with self.connect() as db:
            self._lock_user(db, user_id)
            db.execute("INSERT INTO reading_vectors SELECT message_id,%s,%s FROM chat_readings WHERE message_id=%s AND user_id=%s ON CONFLICT(message_id) DO UPDATE SET signature=excluded.signature,embedding=excluded.embedding", (signature, json.dumps(vector), message_id, user_id))

    @staticmethod
    def _lock_user(db, user_id: str):
        # Serialize changes to the same user's profile, history, and limits.
        db.execute("SELECT id FROM users WHERE id=%s FOR UPDATE", (user_id,))
