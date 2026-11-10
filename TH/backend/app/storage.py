import hashlib
import json
import secrets
import sqlite3
import time
from contextlib import contextmanager
from pathlib import Path
from uuid import uuid4

from .accounts import DUMMY_PASSWORD_HASH, password_hash, password_matches


class Storage:
    def __init__(self, path: str):
        self.path = path
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as db:
            db.executescript("""
                PRAGMA journal_mode=WAL;
                CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY, created REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS accounts(user_id TEXT PRIMARY KEY REFERENCES users(id), username TEXT UNIQUE COLLATE NOCASE NOT NULL, password_hash TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS preferences(user_id TEXT PRIMARY KEY REFERENCES users(id), language TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS companion(user_id TEXT PRIMARY KEY REFERENCES users(id), payload TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS thai_charts(user_id TEXT PRIMARY KEY REFERENCES users(id), fingerprint TEXT NOT NULL, payload TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS sessions(hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), expires REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS profiles(user_id TEXT PRIMARY KEY REFERENCES users(id), revision INTEGER NOT NULL, payload TEXT NOT NULL, chart TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS messages(seq INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT UNIQUE NOT NULL, user_id TEXT NOT NULL REFERENCES users(id), role TEXT NOT NULL, content TEXT NOT NULL, provider TEXT NOT NULL, created REAL NOT NULL);
                CREATE INDEX IF NOT EXISTS messages_user_seq ON messages(user_id, seq);
                CREATE TABLE IF NOT EXISTS memories(id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), content TEXT NOT NULL, created REAL NOT NULL);
                CREATE INDEX IF NOT EXISTS memories_user ON memories(user_id);
                CREATE TABLE IF NOT EXISTS chat_readings(message_id TEXT PRIMARY KEY REFERENCES messages(id) ON DELETE CASCADE, user_id TEXT NOT NULL REFERENCES users(id), content TEXT NOT NULL, evidence TEXT NOT NULL, created REAL NOT NULL);
                CREATE INDEX IF NOT EXISTS readings_user_created ON chat_readings(user_id, created);
                CREATE TABLE IF NOT EXISTS reading_vectors(message_id TEXT PRIMARY KEY REFERENCES chat_readings(message_id) ON DELETE CASCADE, signature TEXT NOT NULL, embedding TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS chat_usage(id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), created REAL NOT NULL);
                CREATE INDEX IF NOT EXISTS chat_usage_user_created ON chat_usage(user_id, created);
                CREATE TABLE IF NOT EXISTS roxy_usage(scope TEXT NOT NULL, created REAL NOT NULL);
                CREATE INDEX IF NOT EXISTS roxy_usage_scope_created ON roxy_usage(scope,created);
            """)

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.path, timeout=5)
        try:
            db.row_factory = sqlite3.Row
            db.execute("PRAGMA foreign_keys=ON")
            with db:
                yield db
        finally:
            db.close()

    def login(self, hours: int):
        user_id, token = str(uuid4()), secrets.token_urlsafe(32)
        with self.connect() as db:
            db.execute("DELETE FROM sessions WHERE expires < ?", (time.time(),))
            db.execute("INSERT INTO users VALUES (?, ?)", (user_id, time.time()))
            db.execute("INSERT INTO sessions VALUES (?, ?, ?)", (self.hash(token), user_id, time.time() + hours * 3600))
        return {"token": token, "user_id": user_id}

    def account(self, user_id: str):
        with self.connect() as db:
            row = db.execute("SELECT username FROM accounts WHERE user_id=?", (user_id,)).fetchone()
        return {"user_id": user_id, "username": row["username"] if row else None, "kind": "account" if row else "demo"}

    def register(self, username: str, password: str, hours: int, existing_user: str | None = None):
        encoded = password_hash(password)
        user_id, token = str(uuid4()), secrets.token_urlsafe(32)
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            # A signed-in anonymous visitor may bind their existing profile to a new account.
            if existing_user and not db.execute("SELECT 1 FROM accounts WHERE user_id=?", (existing_user,)).fetchone():
                user_id = existing_user
            else:
                db.execute("INSERT INTO users VALUES (?, ?)", (user_id, time.time()))
            try:
                db.execute("INSERT INTO accounts VALUES (?, ?, ?)", (user_id, username, encoded))
            except sqlite3.IntegrityError:
                raise ValueError("account_exists") from None
            db.execute("DELETE FROM sessions WHERE user_id=?", (user_id,))
            db.execute("INSERT INTO sessions VALUES (?, ?, ?)", (self.hash(token), user_id, time.time() + hours * 3600))
        return {"token": token, "user_id": user_id}

    def account_login(self, username: str, password: str, hours: int):
        with self.connect() as db:
            row = db.execute("SELECT user_id, password_hash FROM accounts WHERE username=?", (username,)).fetchone()
        matches = password_matches(password, row["password_hash"] if row else DUMMY_PASSWORD_HASH)
        if not row or not matches:
            return None
        token = secrets.token_urlsafe(32)
        with self.connect() as db:
            db.execute("DELETE FROM sessions WHERE expires < ?", (time.time(),))
            db.execute("INSERT INTO sessions VALUES (?, ?, ?)", (self.hash(token), row["user_id"], time.time() + hours * 3600))
        return {"token": token, "user_id": row["user_id"]}

    @staticmethod
    def hash(token: str):
        return hashlib.sha256(token.encode()).hexdigest()

    def authenticate(self, token: str):
        with self.connect() as db:
            row = db.execute("SELECT user_id FROM sessions WHERE hash=? AND expires>?", (self.hash(token), time.time())).fetchone()
        return row[0] if row else None

    def logout(self, token: str):
        with self.connect() as db:
            db.execute("DELETE FROM sessions WHERE hash=?", (self.hash(token),))

    def profile(self, user_id: str):
        with self.connect() as db:
            row = db.execute("SELECT * FROM profiles WHERE user_id=?", (user_id,)).fetchone()
            preference = db.execute("SELECT language FROM preferences WHERE user_id=?", (user_id,)).fetchone()
        if not row:
            return None
        payload = json.loads(row["payload"])
        if preference:
            payload["language"] = preference["language"]
        return {"revision": row["revision"], "profile": payload, "chart": json.loads(row["chart"])}

    def set_language(self, user_id: str, language: str):
        with self.connect() as db:
            db.execute("INSERT INTO preferences VALUES (?,?) ON CONFLICT(user_id) DO UPDATE SET language=excluded.language", (user_id, language))
        return {"language": language}

    def companion(self, user_id: str):
        with self.connect() as db:
            row = db.execute("SELECT payload FROM companion WHERE user_id=?", (user_id,)).fetchone()
        return json.loads(row["payload"]) if row else None

    def save_companion(self, user_id: str, payload: dict):
        with self.connect() as db:
            db.execute("INSERT INTO companion VALUES (?,?) ON CONFLICT(user_id) DO UPDATE SET payload=excluded.payload", (user_id, json.dumps(payload)))
        return payload

    def thai_chart(self, user_id: str, fingerprint: str):
        with self.connect() as db:
            row = db.execute("SELECT payload FROM thai_charts WHERE user_id=? AND fingerprint=?", (user_id, fingerprint)).fetchone()
        return json.loads(row["payload"]) if row else None

    def save_thai_chart(self, user_id: str, fingerprint: str, payload: dict):
        with self.connect() as db:
            db.execute("INSERT INTO thai_charts VALUES (?,?,?) ON CONFLICT(user_id) DO UPDATE SET fingerprint=excluded.fingerprint,payload=excluded.payload", (user_id, fingerprint, json.dumps(payload)))
        return payload

    def save_profile(self, user_id: str, payload: dict, chart: dict):
        with self.connect() as db:
            previous = db.execute("SELECT payload FROM profiles WHERE user_id=?", (user_id,)).fetchone()
            birth_fields = ("birth_date", "birth_time", "timezone", "birthplace", "country_code", "location_id", "latitude", "longitude")
            old_profile = json.loads(previous["payload"]) if previous else {}
            birth_changed = any(old_profile.get(field) != payload.get(field) for field in birth_fields)
            db.execute(
                """INSERT INTO profiles VALUES (?, 1, ?, ?) ON CONFLICT(user_id)
                DO UPDATE SET revision=revision+1, payload=excluded.payload, chart=excluded.chart""",
                (user_id, json.dumps(payload), json.dumps(chart)),
            )
            if birth_changed:
                db.execute("DELETE FROM messages WHERE user_id=?", (user_id,))
        return self.profile(user_id)

    def history(self, user_id: str, limit: int = 60):
        with self.connect() as db:
            rows = db.execute(
                "SELECT m.id, m.role, m.content, m.provider, m.created, r.evidence FROM messages m LEFT JOIN chat_readings r ON r.message_id=m.id AND r.user_id=m.user_id WHERE m.user_id=? ORDER BY m.seq DESC LIMIT ?", (user_id, limit)
            ).fetchall()
        return [{**{key: row[key] for key in ("id", "role", "content", "provider", "created")}, **({"evidence": json.loads(row["evidence"])} if row["evidence"] else {})} for row in reversed(rows)]

    def save_pair(self, user_id: str, question: str, answer: str, provider: str, evidence: dict | None = None):
        answer_id = str(uuid4())
        with self.connect() as db:
            db.executemany(
                "INSERT INTO messages(id,user_id,role,content,provider,created) VALUES (?,?,?,?,?,?)",
                [(str(uuid4()), user_id, "user", question, provider, time.time()), (answer_id, user_id, "assistant", answer, provider, time.time())],
            )
            if evidence is not None:
                db.execute("INSERT INTO chat_readings VALUES (?,?,?,?,?)", (answer_id, user_id, "User: " + question + "\n\nAssistant: " + answer, json.dumps(evidence), time.time()))
        return answer_id

    def clear_history(self, user_id: str):
        with self.connect() as db:
            db.execute("DELETE FROM messages WHERE user_id=?", (user_id,))

    def memories(self, user_id: str):
        with self.connect() as db:
            rows = db.execute("SELECT id, content, created FROM memories WHERE user_id=? ORDER BY created", (user_id,)).fetchall()
        return [{**dict(row), "source": "user_confirmed"} for row in rows]

    def add_memory(self, user_id: str, content: str):
        memory_id = str(uuid4())
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            if db.execute("SELECT COUNT(*) FROM memories WHERE user_id=?", (user_id,)).fetchone()[0] >= 20:
                raise ValueError("memory_limit")
            db.execute("INSERT INTO memories VALUES (?,?,?,?)", (memory_id, user_id, content, time.time()))
        return next(item for item in self.memories(user_id) if item["id"] == memory_id)

    def delete_memory(self, user_id: str, memory_id: str):
        with self.connect() as db:
            return db.execute("DELETE FROM memories WHERE user_id=? AND id=?", (user_id, memory_id)).rowcount > 0

    def update_memory(self, user_id: str, memory_id: str, content: str):
        with self.connect() as db:
            if not db.execute("UPDATE memories SET content=? WHERE user_id=? AND id=?", (content, user_id, memory_id)).rowcount:
                return None
        return next(item for item in self.memories(user_id) if item["id"] == memory_id)

    def reserve_chat(self, user_id: str, per_minute: int, per_day: int):
        # Ported from Roxy's chat-limit.ts; count attempts to also bound failed paid calls.
        now = time.time()
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            db.execute("DELETE FROM chat_usage WHERE created<?", (now - 86400,))
            minute, day = db.execute("SELECT COALESCE(SUM(created>=?),0),COUNT(*) FROM chat_usage WHERE user_id=? AND created>=?", (now - 60, user_id, now - 86400)).fetchone()
            if day >= per_day:
                return "chat_daily_limit"
            if minute >= per_minute:
                return "chat_minute_limit"
            db.execute("INSERT INTO chat_usage VALUES (?,?,?)", (str(uuid4()), user_id, now))
        return None

    def reserve_roxy(self, scopes: list[str], per_minute: int, per_day: int):
        now = time.time()
        scopes = list(set(scopes))
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            db.execute("DELETE FROM roxy_usage WHERE created<?", (now - 86400,))
            for scope in scopes:
                minute, day = db.execute(
                    "SELECT COALESCE(SUM(created>=?),0),COUNT(*) FROM roxy_usage WHERE scope=? AND created>=?",
                    (now - 60, scope, now - 86400),
                ).fetchone()
                if minute >= per_minute or day >= per_day:
                    return False
            db.executemany("INSERT INTO roxy_usage VALUES (?,?)", [(scope, now) for scope in scopes])
        return True

    def recall_readings(self, user_id: str, signature: str):
        with self.connect() as db:
            rows = db.execute("SELECT r.message_id AS id,r.content,r.created,v.embedding FROM chat_readings r LEFT JOIN reading_vectors v ON v.message_id=r.message_id AND v.signature=? WHERE r.user_id=? ORDER BY r.created DESC LIMIT 200", (signature, user_id)).fetchall()
        return [dict(row) for row in rows]

    def reading(self, user_id: str, message_id: str):
        with self.connect() as db:
            row = db.execute("SELECT message_id AS id,content,created FROM chat_readings WHERE user_id=? AND message_id=?", (user_id, message_id)).fetchone()
        return dict(row) if row else None

    def index_reading(self, user_id: str, message_id: str, signature: str, vector: list):
        # The guarded SELECT prevents a delayed embedding resurrecting deleted history.
        with self.connect() as db:
            db.execute("INSERT INTO reading_vectors SELECT message_id,?,? FROM chat_readings WHERE message_id=? AND user_id=? ON CONFLICT(message_id) DO UPDATE SET signature=excluded.signature,embedding=excluded.embedding", (signature, json.dumps(vector), message_id, user_id))
