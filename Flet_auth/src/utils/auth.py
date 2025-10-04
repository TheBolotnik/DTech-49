# src/utils/auth.py
import os
import json
import hashlib
import secrets
import base64
from typing import Tuple, Optional

APP_DIR_NAME = "Flet_Prod"
DB_FILE = "app_db.json"


def _app_dir() -> str:
    base = os.environ.get("APPDATA") or os.path.join(os.path.expanduser("~"), ".config")
    path = os.path.join(base, APP_DIR_NAME)
    os.makedirs(path, exist_ok=True)
    return path


def _db_path() -> str:
    return os.path.join(_app_dir(), DB_FILE)


def _load_db() -> dict:
    try:
        with open(_db_path(), "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}
    except Exception:
        return {}


def _save_db(d: dict) -> None:
    with open(_db_path(), "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)


def get_credentials() -> Tuple[Optional[str], Optional[str], Optional[str]]:
    """Возвращает (api_key, pin_hash, pin_salt)."""
    d = _load_db()
    return d.get("api_key"), d.get("pin_hash"), d.get("pin_salt")


def _hash_pin(pin: str, salt_b64: str) -> str:
    salt = base64.b64decode(salt_b64)
    dk = hashlib.pbkdf2_hmac("sha256", pin.encode("utf-8"), salt, 100_000)
    return base64.b64encode(dk).decode("utf-8")


def verify_pin(pin: str) -> bool:
    _, pin_hash, pin_salt = get_credentials()
    if not (pin_hash and pin_salt):
        return False
    return _hash_pin(pin, pin_salt) == pin_hash


def save_credentials(api_key: str, pin: str) -> None:
    """Сохраняет ключ (в явном виде) и хэш от PIN (с солью)."""
    salt_b64 = base64.b64encode(secrets.token_bytes(16)).decode("utf-8")
    pin_hash = _hash_pin(pin, salt_b64)
    d = _load_db()
    d.update({"api_key": api_key, "pin_hash": pin_hash, "pin_salt": salt_b64})
    _save_db(d)


def set_api_key(api_key: str) -> None:
    d = _load_db()
    d["api_key"] = api_key
    _save_db(d)


def clear_credentials() -> None:
    _save_db({})
