import os
import json
import base64
import hashlib
import secrets
import importlib
import inspect
from typing import Optional, Tuple

import flet as ft
import requests


# Конфиг / хранилище

APP_DIR_NAME = "Flet_Prod"
DB_FILE = "app_db.json"
OPENROUTER_BASE = "https://openrouter.ai/api/v1"


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
    """Сохраняет ключ (в явном виде) и хэш от PIN."""
    salt_b64 = base64.b64encode(secrets.token_bytes(16)).decode("utf-8")
    pin_hash = _hash_pin(pin, salt_b64)
    d = _load_db()
    d.update({"api_key": api_key, "pin_hash": pin_hash, "pin_salt": salt_b64})
    _save_db(d)


def clear_credentials() -> None:
    _save_db({})


# Проверка ключа OpenRouter (валидность + баланс > 0)

def check_api_key_balance(api_key: str) -> Tuple[bool, float, str]:
    """
    Возвращает (is_ok, balance, error_message).
    Баланс = total_credits - total_usage.
    """
    try:
        r = requests.get(
            f"{OPENROUTER_BASE}/credits",
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=15,
        )
        if r.status_code in (401, 403):
            return False, 0.0, "Неверный ключ OpenRouter"
        if r.status_code == 429:
            return False, 0.0, "Превышены лимиты. Попробуйте позже."
        r.raise_for_status()
        data = r.json().get("data", {})
        total = float(data.get("total_credits", 0.0))
        used = float(data.get("total_usage", 0.0))
        balance = total - used
        return (balance > 0.0), balance, ""
    except requests.HTTPError as e:
        return False, 0.0, f"HTTP ошибка: {getattr(e.response, 'text', str(e))}"
    except requests.RequestException as e:
        return False, 0.0, f"Ошибка сети: {e}"
    except Exception as e:
        return False, 0.0, f"Непредвиденная ошибка: {e}"


# Login UI


def make_login_card(page: ft.Page, on_success):
    mode = "pin" if get_credentials()[0] else "first"

    # refs
    api_key_tf = ft.Ref[ft.TextField]()
    pin_tf = ft.Ref[ft.TextField]()
    msg = ft.Ref[ft.Text]()
    progress = ft.Ref[ft.ProgressRing]()
    btn_check = ft.Ref[ft.ElevatedButton]()
    btn_login = ft.Ref[ft.ElevatedButton]()
    btn_reset = ft.Ref[ft.TextButton]()

    def switch_mode(new_mode: str):
        nonlocal mode
        mode = new_mode
        if api_key_tf.current:
            api_key_tf.current.visible = (mode == "first")
        if btn_check.current:
            btn_check.current.visible = (mode == "first")
        if pin_tf.current:
            pin_tf.current.visible = (mode == "pin")
        if btn_login.current:
            btn_login.current.visible = (mode == "pin")
        if btn_reset.current:
            btn_reset.current.visible = (mode == "pin")
        if msg.current:
            msg.current.value = ""
        page.update()

    def on_reset_click(_):
        clear_credentials()
        if api_key_tf.current:
            api_key_tf.current.value = ""
        if pin_tf.current:
            pin_tf.current.value = ""
        switch_mode("first")

    def on_check_click(_):
        key = (api_key_tf.current.value or "").strip() if api_key_tf.current else ""
        if not key:
            msg.current.value = "Введите ключ OpenRouter"
            page.update()
            return

        progress.current.visible = True
        page.update()

        ok, balance, err = check_api_key_balance(key)

        progress.current.visible = False
        if not ok:
            msg.current.value = err or "Недостаточный баланс или неверный ключ"
            page.update()
            return

        # Генерируем PIN и сохраняем
        pin = f"{secrets.randbelow(10_000):04d}"
        save_credentials(key, pin)

        # Показываем PIN пользователю ОДИН раз
        dlg = ft.AlertDialog(
            modal=True,
            title=ft.Text("PIN сгенерирован"),
            content=ft.Text(f"Ваш PIN: {pin}\nСохраните его — он потребуется при входе."),
            actions=[ft.TextButton("ОК", on_click=lambda e: page.close(dlg))],
            actions_alignment=ft.MainAxisAlignment.END,
        )
        page.open(dlg)

        msg.current.value = f"Баланс: {balance:.2f}. Ключ сохранён. Перейдите к входу по PIN."
        switch_mode("pin")

    def on_login_click(_):
        pin = (pin_tf.current.value or "").strip() if pin_tf.current else ""
        if len(pin) != 4 or not pin.isdigit():
            msg.current.value = "Введите 4-значный PIN"
            page.update()
            return
        if not verify_pin(pin):
            msg.current.value = "Неверный PIN"
            page.update()
            return
        api_key, _, _ = get_credentials()
        if callable(on_success):
            on_success(api_key)

    card = ft.Card(
        content=ft.Container(
            padding=20,
            width=520,
            content=ft.Column(
                spacing=12,
                alignment=ft.MainAxisAlignment.CENTER,
                controls=[
                    ft.Text("Авторизация", size=22, weight=ft.FontWeight.BOLD),
                    ft.TextField(
                        ref=api_key_tf,
                        label="OpenRouter API key",
                        password=True,
                        visible=(mode == "first"),
                        expand=True,
                    ),
                    ft.TextField(
                        ref=pin_tf,
                        label="PIN (4 цифры)",
                        password=True,
                        keyboard_type=ft.KeyboardType.NUMBER,
                        max_length=4,
                        visible=(mode == "pin"),
                        expand=True,
                    ),
                    ft.Row(
                        controls=[
                            ft.ElevatedButton("Проверить и сохранить",
                                              ref=btn_check,
                                              visible=(mode == "first"),
                                              on_click=on_check_click
                                              ),
                            ft.ElevatedButton("Войти",
                                              ref=btn_login,
                                              visible=(mode == "pin"),
                                              on_click=on_login_click
                                              ),
                            ft.TextButton("Сбросить ключ",
                                          ref=btn_reset,
                                          visible=(mode == "pin"),
                                          on_click=on_reset_click
                                          ),
                            ft.ProgressRing(ref=progress, visible=False),
                        ],
                        wrap=False,
                    ),
                    ft.Text(value="", ref=msg, color=ft.Colors.RED),
                    ft.TextButton("Где взять API ключ?", url="https://openrouter.ai/keys"),
                ],
            ),
        )
    )
    return card

# Запуск UI из main.py


def launch_legacy_ui(page: ft.Page):
    """
    Импортирует исходный main.py и запускает UI без изменений.

    Приоритет:
      1) main.ChatApp().main(page)
      2) функция с 1 параметром (page) — напр., app_main(page), render(page), ...
      3) main(page) с 1 параметром

    Функции без параметров (например, main() с внутренним ft.app(...)) не вызывается изнутри —
    это породит вторую Flet-аппу. В таком случае покажет понятную подсказку.
    """
    page.clean()

    try:
        m = importlib.import_module("main")
    except Exception as e:
        page.add(ft.Text(f"Не удалось импортировать main.py: {e}", color=ft.Colors.RED))
        page.update()
        return

    # 1) Класс ChatApp с методом main(self, page)
    if hasattr(m, "ChatApp"):
        try:
            app = m.ChatApp()
            if hasattr(app, "main") and callable(app.main):
                sig = inspect.signature(app.main)
                if len(sig.parameters) == 1:
                    app.main(page)
                    return
        except Exception as e:
            page.add(ft.Text(f"Ошибка при запуске ChatApp.main(page): {e}", color=ft.Colors.RED))
            page.update()
            return

    # 2) Любая функция с одним параметром — вызов с page
    callable_attrs = [(name, getattr(m, name)) for name in dir(m) if callable(getattr(m, name))]
    public_funcs = [(n, f) for n, f in callable_attrs if not n.startswith("_")]

    preferred_names = {"app_main", "render", "build_ui", "start", "run", "ui", "entry", "bootstrap", "main"}
    sorted_funcs = sorted(public_funcs, key=lambda t: (t[0] not in preferred_names, t[0]))

    for name, func in sorted_funcs:
        try:
            sig = inspect.signature(func)
        except (TypeError, ValueError):
            continue
        if len(sig.parameters) == 1:
            try:
                func(page)
                return
            except Exception as e:
                page.add(ft.Text(f"Ошибка при вызове {name}(page): {e}", color=ft.Colors.RED))
                page.update()
                return

    # 3) Спец-обработка: если main() без параметров — ошибка с пояснением
    if hasattr(m, "main") and callable(m.main):
        try:
            sig = inspect.signature(m.main)
            if len(sig.parameters) == 0:
                page.add(
                    ft.Column(
                        controls=[
                            ft.Text("В main.py найден main() БЕЗ параметров.", size=18, weight=ft.FontWeight.BOLD),
                            ft.Text(
                                "Его нельзя запускать изнутри auth_gate, т.к. он сам создаёт новую Flet-аппу."
                            ),
                            ft.Text(
                                "Решения:\n"
                                "  • Добавьте в main.py функцию вида app_main(page: ft.Page) и позвольте auth_gate её вызвать\n"
                                "  • ИЛИ оставьте класс ChatApp с методом main(self, page) — auth_gate запустит его\n"
                                "  • Третий вариант: сделайте отдельный файл с page-хендлером и импортируйте его в main.py",
                                color=ft.Colors.GREY_700,
                            ),
                        ],
                        spacing=8,
                    )
                )
                page.update()
                return
        except Exception as e:
            page.add(ft.Text(f"Ошибка анализа сигнатуры main(): {e}", color=ft.Colors.RED))
            page.update()
            return

    # Если сюда дошли — подходящей точки входа не нашли
    page.add(
        ft.Column(
            controls=[
                ft.Text("Не нашёл подходящую точку входа в main.py", size=18, weight=ft.FontWeight.BOLD),
                ft.Text(
                    "Экспортируйте либо класс ChatApp с методом main(self, page), "
                    "либо функцию с одним параметром (page).",
                    color=ft.Colors.GREY_700,
                ),
            ],
            spacing=8,
        )
    )
    page.update()


# Старт: сначала логин → затем UI из main.py

def boot(page: ft.Page):
    page.theme_mode = ft.ThemeMode.LIGHT
    page.horizontal_alignment = ft.CrossAxisAlignment.CENTER
    page.vertical_alignment = ft.MainAxisAlignment.CENTER

    def on_success(api_key: str):
        os.environ["OPENROUTER_API_KEY"] = api_key
        page.session.set("OPENROUTER_API_KEY", api_key)
        launch_legacy_ui(page)

    login_card = make_login_card(page, on_success)
    page.add(ft.Container(expand=True, alignment=ft.alignment.center, content=login_card))
    page.update()


if __name__ == "__main__":
    ft.app(target=boot)
