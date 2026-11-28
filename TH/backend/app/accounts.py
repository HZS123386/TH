import hashlib
import hmac
import secrets

# OWASP's 32 MiB scrypt configuration; password work runs off the event loop.
SCRYPT_N, SCRYPT_R, SCRYPT_P = 2**15, 8, 3
H5_LOGIN_SECONDS = 600
H5_LOGIN_RETENTION_AFTER_EXPIRY = 7 * 86400 - H5_LOGIN_SECONDS


def new_h5_login_code() -> str:
    letters = "ABCDEFGHJKMNPQRSTUVWXYZ"
    digits = "23456789"
    while True:
        code = "".join(secrets.choice(letters + digits) for _ in range(6))
        if any(char in letters for char in code) and any(char in digits for char in code):
            return code


def password_hash(password: str, salt: str | None = None) -> str:
    salt = salt or secrets.token_hex(16)
    digest = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=SCRYPT_N, r=SCRYPT_R, p=SCRYPT_P, maxmem=64 * 1024 * 1024).hex()
    return f"scrypt-v1${salt}${digest}"


def password_matches(password: str, encoded: str) -> bool:
    scheme, salt, _ = encoded.split("$")
    return scheme == "scrypt-v1" and hmac.compare_digest(password_hash(password, salt), encoded)


# Run the same expensive operation for missing usernames to avoid a cheap lookup path.
DUMMY_PASSWORD_HASH = password_hash(secrets.token_urlsafe(32))
