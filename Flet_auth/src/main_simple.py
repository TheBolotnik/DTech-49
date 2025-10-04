# Импорт необходимых библиотек
import flet as ft  # Основной фреймворк для создания GUI
from api import OpenRouterClient  # Клиент для работы с API OpenRouter
from ui import MessageBubble  # Компонент для отображения сообщений
import asyncio  # Библиотека для асинхронного программирования

class SimpleChatApp:
    def __init__(self):
        # Инициализация основных компонентов приложения
        self.api_client = OpenRouterClient()  # Клиент для API

    def main(self, page: ft.Page):
        # Настройка основных параметров страницы
        page.title = "Simple AI Chat"  # Заголовок окна
        page.vertical_alignment = ft.MainAxisAlignment.CENTER  # Вертикальное выравнивание
        page.horizontal_alignment = ft.CrossAxisAlignment.CENTER  # Горизонтальное выравнивание
        page.padding = 20  # Отступы страницы
        page.bgcolor = ft.Colors.GREY_900  # Цвет фона
        page.theme_mode = ft.ThemeMode.DARK  # Тёмная тема

        # Создание области истории чата
        self.chat_history = ft.Column(
            scroll=ft.ScrollMode.AUTO,  # Автоматическая прокрутка
            expand=True,  # Расширение на доступное пространство
            spacing=10,  # Отступ между сообщениями
            auto_scroll=True  # Автопрокрутка к новым сообщениям
        )

        # Создание поля ввода сообщения
        self.message_input = ft.TextField(
            expand=True,  # Расширение на доступную ширину
            height=50,  # Высота поля ввода
            multiline=False,  # Однострочный режим
            text_size=16,  # Размер текста
            color=ft.Colors.WHITE,  # Цвет текста
            bgcolor=ft.Colors.GREY_800,  # Цвет фона поля
            border_color=ft.Colors.BLUE_400,  # Цвет границы
            cursor_color=ft.Colors.WHITE,  # Цвет курсора
            content_padding=10,  # Внутренние отступы текста
            border_radius=8,  # Радиус скругления углов
            hint_text="Введите сообщение здесь..."  # Текст-подсказка в пустом поле
        )

        async def send_message(e):
            # Проверка на пустое сообщение
            if not self.message_input.value:
                return

            # Получение текста сообщения и очистка поля ввода
            user_message = self.message_input.value
            self.message_input.value = ""
            page.update()

            # Добавление сообщения пользователя в чат
            self.chat_history.controls.append(
                MessageBubble(message=user_message, is_user=True)
            )

            # Отображение индикатора загрузки
            loading = ft.ProgressRing()
            self.chat_history.controls.append(loading)
            page.update()

            # Асинхронная отправка запроса к API
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                lambda: self.api_client.send_message(
                    user_message,
                    "openai/gpt-3.5-turbo"
                )
            )

            # Удаление индикатора загрузки
            self.chat_history.controls.remove(loading)

            # Обработка ответа от API
            if "error" in response:
                response_text = f"Ошибка: {response['error']}"
            else:
                response_text = response["choices"][0]["message"]["content"]

            # Добавление ответа в чат
            self.chat_history.controls.append(
                MessageBubble(message=response_text, is_user=False)
            )
            page.update()

        # Создание кнопки отправки сообщения
        send_button = ft.IconButton(
            icon=ft.Icons.SEND_ROUNDED,  # Иконка отправки
            icon_color=ft.Colors.BLUE_400,  # Цвет иконки
            on_click=send_message  # Обработчик нажатия
        )

        # Добавление всех элементов на страницу
        page.add(
            ft.Container(
                content=ft.Column([
                    self.chat_history,  # История чата
                    ft.Row([
                        self.message_input,  # Поле ввода
                        send_button  # Кнопка отправки
                    ], alignment=ft.MainAxisAlignment.CENTER)  # Выравнивание по центру
                ]),
                width=800,  # Базовая ширина контейнера
                expand=True,  # Расширение по высоте
                padding=10,  # Внутренние отступы
                bgcolor=ft.Colors.GREY_800  # Цвет фона контейнера
            )
        )

# Точка входа в приложение
if __name__ == "__main__":
    app = SimpleChatApp()  # Создание экземпляра приложения
    ft.app(target=app.main)  # Запуск приложения
