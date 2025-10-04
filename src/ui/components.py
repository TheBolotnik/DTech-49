# Импорт необходимых библиотек и модулей
import flet as ft  # Фреймворк для создания пользовательского интерфейса
from .styles import AppStyles
from api.openrouter import check_api_key_balance
from utils import auth
import secrets


class MessageBubble(ft.Container):
    """
    Компонент "пузырька" сообщения в чате.

    Наследуется от ft.Container для создания стилизованного контейнера сообщения.
    Отображает сообщения пользователя и AI с разными стилями и позиционированием.

    Args:
        message (str): Текст сообщения для отображения
        is_user (bool): Флаг, указывающий, является ли это сообщением пользователя
    """

    def __init__(self, message: str, is_user: bool):
        # Инициализация родительского класса Container
        super().__init__()

        # Настройка отступов внутри пузырька
        self.padding = 10

        # Настройка скругления углов пузырька
        self.border_radius = 10

        # Установка цвета фона в зависимости от отправителя:
        # - Синий для сообщений пользователя
        # - Серый для сообщений AI
        self.bgcolor = ft.Colors.BLUE_700 if is_user else ft.Colors.GREY_700

        # Установка выравнивания пузырька:
        # - Справа для сообщений пользователя
        # - Слева для сообщений AI
        self.alignment = ft.alignment.center_right if is_user else ft.alignment.center_left

        # Настройка внешних отступов для создания эффекта диалога:
        # - Отступ слева для сообщений пользователя
        # - Отступ справа для сообщений AI
        # - Небольшие отступы сверху и снизу для разделения сообщений
        self.margin = ft.margin.only(
            left=50 if is_user else 0,  # Отступ слева
            right=0 if is_user else 50,  # Отступ справа
            top=5,  # Отступ сверху
            bottom=5  # Отступ снизу
        )

        # Создание содержимого пузырька
        self.content = ft.Column(
            controls=[
                # Текст сообщения с настройками отображения
                ft.Text(
                    value=message,  # Текст сообщения
                    color=ft.Colors.WHITE,  # Белый цвет текста
                    size=16,  # Размер шрифта
                    selectable=True,  # Возможность выделения текста
                    weight=ft.FontWeight.W_400  # Нормальная толщина шрифта
                )
            ],
            tight=True  # Плотное расположение элементов в колонке
        )


class ModelSelector(ft.Dropdown):
    """
    Выпадающий список для выбора AI модели с функцией поиска.

    Наследуется от ft.Dropdown для создания кастомного выпадающего списка
    с дополнительным полем поиска для фильтрации моделей.

    Args:
        models (list): Список доступных моделей в формате:
                      [{"id": "model-id", "name": "Model Name"}, ...]
    """

    def __init__(self, models: list):
        # Инициализация родительского класса Dropdown
        super().__init__()

        # Применение стилей из конфигурации к компоненту
        for key, value in AppStyles.MODEL_DROPDOWN.items():
            setattr(self, key, value)

        # Настройка внешнего вида выпадающего списка
        self.label = None  # Убираем текстовую метку
        self.hint_text = "Выбор модели"  # Текст-подсказка

        # Создание списка опций из предоставленных моделей
        self.options = [
            ft.dropdown.Option(
                key=model['id'],  # ID модели как ключ
                text=model['name']  # Название модели как отображаемый текст
            ) for model in models
        ]

        # Сохранение полного списка опций для фильтрации
        self.all_options = self.options.copy()

        # Установка начального значения (первая модель из списка)
        self.value = models[0]['id'] if models else None

        # Создание поля поиска для фильтрации моделей
        self.search_field = ft.TextField(
            on_change=self.filter_options,  # Функция обработки изменений
            hint_text="Поиск модели",  # Текст-подсказка в поле поиска
            **AppStyles.MODEL_SEARCH_FIELD  # Применение стилей из конфигурации
        )

    def filter_options(self, e):
        """
        Фильтрация списка моделей на основе введенного текста поиска.

        Args:
            e: Событие изменения текста в поле поиска
        """
        # Получение текста поиска в нижнем регистре
        search_text = self.search_field.value.lower() if self.search_field.value else ""

        # Если поле поиска пустое - показываем все модели
        if not search_text:
            self.options = self.all_options
        else:
            # Фильтрация моделей по тексту поиска
            # Ищем совпадения в названии или ID модели
            self.options = [
                opt for opt in self.all_options
                if search_text in opt.text.lower() or search_text in opt.key.lower()
            ]

        # Обновление интерфейса для отображения отфильтрованного списка
        e.page.update()


class LoginCard(ft.UserControl):
    """
    Экран авторизации:
      - mode="first": ввод OpenRouter API Key, проверка и сохранение, генерация PIN
      - mode="pin": ввод PIN + кнопка "Сбросить ключ"
    """
    def __init__(self, on_success):
        super().__init__()
        self.on_success = on_success
        # Если ключ уже есть — переходим в режим PIN
        self.mode = "pin" if auth.get_credentials()[0] else "first"

        # UI элементы
        self.title = ft.Text("Авторизация", style=ft.TextThemeStyle.HEADLINE_MEDIUM)

        self.api_key_tf = ft.TextField(
            label="OpenRouter API key",
            password=True,
            visible=self.mode == "first",
            expand=True,
        )

        self.pin_tf = ft.TextField(
            label="PIN (4 цифры)",
            password=True,
            keyboard_type=ft.KeyboardType.NUMBER,
            max_length=4,
            visible=self.mode == "pin",
            expand=True,
        )

        self.msg = ft.Text(value="", color=ft.Colors.RED)
        self.progress = ft.ProgressRing(visible=False)

        self.btn_check = ft.ElevatedButton(
            "Проверить и сохранить",
            on_click=self.on_check_click,
            visible=self.mode == "first",
        )
        self.btn_login = ft.ElevatedButton(
            "Войти",
            on_click=self.on_login_click,
            visible=self.mode == "pin",
        )
        self.btn_reset = ft.TextButton(
            "Сбросить ключ",
            on_click=self.on_reset_click,
            visible=self.mode == "pin",
        )

    def build(self):
        return ft.Card(
            content=ft.Container(
                padding=20,
                width=520,
                content=ft.Column(
                    spacing=12,
                    alignment=ft.MainAxisAlignment.CENTER,
                    controls=[
                        self.title,
                        self.api_key_tf,
                        self.pin_tf,
                        ft.Row(
                            controls=[self.btn_check, self.btn_login, self.btn_reset, self.progress],
                            wrap=False,
                        ),
                        self.msg,
                        ft.TextButton(
                            "Где взять API ключ?",
                            url="https://openrouter.ai/keys",
                        ),
                    ],
                ),
            )
        )

    def _switch_mode(self, mode: str):
        self.mode = mode
        self.api_key_tf.visible = mode == "first"
        self.btn_check.visible = mode == "first"
        self.pin_tf.visible = mode == "pin"
        self.btn_login.visible = mode == "pin"
        self.btn_reset.visible = mode == "pin"
        self.msg.value = ""
        self.update()

    def on_reset_click(self, _):
        # Полный сброс (переводим в первичный сценарий)
        auth.clear_credentials()
        self.api_key_tf.value = ""
        self.pin_tf.value = ""
        self._switch_mode("first")

    def on_check_click(self, _):
        key = (self.api_key_tf.value or "").strip()
        if not key:
            self.msg.value = "Введите ключ OpenRouter"
            self.update()
            return

        self.progress.visible = True
        self.update()

        ok, balance, err = check_api_key_balance(key)

        self.progress.visible = False

        if not ok:
            self.msg.value = err or "Недостаточный баланс или неверный ключ"
            self.update()
            return

        # Генерируем PIN и сохраняем
        pin = f"{secrets.randbelow(10_000):04d}"
        auth.save_credentials(key, pin)

        # Показываем пользователю PIN один раз
        dlg = ft.AlertDialog(
            modal=True,
            title=ft.Text("PIN сгенерирован"),
            content=ft.Text(f"Ваш PIN: {pin}\nСохраните его — он потребуется при входе."),
            actions=[ft.TextButton("ОК", on_click=lambda e: self.page.close(dlg))],
            actions_alignment=ft.MainAxisAlignment.END,
        )
        self.page.open(dlg)

        self.msg.value = f"Баланс: {balance:.2f}. Ключ сохранён. Перейдите к входу по PIN."
        self._switch_mode("pin")

    def on_login_click(self, _):
        pin = (self.pin_tf.value or "").strip()
        if len(pin) != 4 or not pin.isdigit():
            self.msg.value = "Введите 4-значный PIN"
            self.update()
            return

        if not auth.verify_pin(pin):
            self.msg.value = "Неверный PIN"
            self.update()
            return

        # Успех
        api_key, _, _ = auth.get_credentials()
        if callable(self.on_success):
            self.on_success(api_key)
