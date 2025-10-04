import flet as ft  # Импортируем фреймворк Flet для создания пользовательского интерфейса


class AppStyles:
    """
    Класс для централизованного хранения всех стилей приложения.

    Содержит константы и конфигурации для всех визуальных элементов интерфейса:
    - Настройки страницы
    - Стили компонентов чата
    - Настройки кнопок
    - Параметры полей ввода
    - Конфигурации layout элементов
    """

    # Основные настройки страницы приложения
    PAGE_SETTINGS = {
        "title": "AI Chat",  # Заголовок окна приложения
        "vertical_alignment": ft.MainAxisAlignment.CENTER,  # Вертикальное выравнивание содержимого по центру
        "horizontal_alignment": ft.CrossAxisAlignment.CENTER,  # Горизонтальное выравнивание содержимого по центру
        "padding": 20,  # Отступы от краев окна
        "bgcolor": ft.Colors.GREY_900,  # Темно-серый цвет фона для темной темы
        "theme_mode": ft.ThemeMode.DARK,  # Использование темной темы оформления
    }

    # Настройки области истории чата
    CHAT_HISTORY = {
        "expand": True,  # Разрешаем расширение на все доступное пространство
        "spacing": 10,  # Отступ между сообщениями в пикселях
        "height": 400,  # Фиксированная высота области чата
        "auto_scroll": True,  # Автоматическая прокрутка к новым сообщениям
        "padding": 20,  # Внутренние отступы области чата
    }

    # Настройки поля ввода сообщений
    MESSAGE_INPUT = {
        "width": 400,  # Ширина поля ввода в пикселях
        "height": 50,  # Высота поля ввода в пикселях
        "multiline": False,  # Запрет многострочного ввода
        "text_size": 16,  # Размер шрифта текста
        "color": ft.Colors.WHITE,  # Цвет вводимого текста
        "bgcolor": ft.Colors.GREY_800,  # Цвет фона поля ввода
        "border_color": ft.Colors.BLUE_400,  # Цвет границы поля
        "cursor_color": ft.Colors.WHITE,  # Цвет курсора ввода
        "content_padding": 10,  # Внутренние отступы текста
        "border_radius": 8,  # Радиус скругления углов
        "hint_text": "Введите сообщение здесь...",  # Текст-подсказка в пустом поле
        "shift_enter": True,  # Включение отправки по Shift+Enter
    }

    # Настройки кнопки отправки сообщения
    SEND_BUTTON = {
        "text": "Отправка",  # Текст на кнопке
        "icon": ft.Icons.SEND,  # Иконка отправки сообщения
        "style": ft.ButtonStyle(  # Стиль оформления кнопки
            color=ft.Colors.WHITE,  # Цвет текста кнопки
            bgcolor=ft.Colors.BLUE_700,  # Цвет фона кнопки
            padding=10,  # Внутренние отступы
        ),
        "tooltip": "Отправить сообщение",  # Всплывающая подсказка при наведении
        "height": 40,  # Высота кнопки
        "width": 130,  # Ширина кнопки
    }

    # Настройки кнопки сохранения диалога
    SAVE_BUTTON = {
        "text": "Сохранить",  # Текст на кнопке
        "icon": ft.Icons.SAVE,  # Иконка сохранения
        "style": ft.ButtonStyle(  # Стиль оформления кнопки
            color=ft.Colors.WHITE,  # Цвет текста
            bgcolor=ft.Colors.BLUE_700,  # Цвет фона
            padding=10,  # Внутренние отступы
        ),
        "tooltip": "Сохранить диалог в файл",  # Всплывающая подсказка
        "width": 130,  # Ширина кнопки
        "height": 40,  # Высота кнопки
    }

    # Настройки кнопки очистки истории
    CLEAR_BUTTON = {
        "text": "Очистить",  # Текст на кнопке
        "icon": ft.Icons.DELETE,  # Иконка удаления
        "style": ft.ButtonStyle(  # Стиль оформления кнопки
            color=ft.Colors.WHITE,  # Цвет текста
            bgcolor=ft.Colors.RED_700,  # Красный цвет фона для предупреждения
            padding=10,  # Внутренние отступы
        ),
        "tooltip": "Очистить историю чата",  # Всплывающая подсказка
        "width": 130,  # Ширина кнопки
        "height": 40,  # Высота кнопки
    }

    # Настройки кнопки показа аналитики
    ANALYTICS_BUTTON = {
        "text": "Аналитика",  # Текст на кнопке
        "icon": ft.Icons.ANALYTICS,  # Иконка аналитики
        "style": ft.ButtonStyle(  # Стиль оформления кнопки
            color=ft.Colors.WHITE,  # Цвет текста
            bgcolor=ft.Colors.GREEN_700,  # Зеленый цвет фона
            padding=10,  # Внутренние отступы
        ),
        "tooltip": "Показать аналитику",  # Всплывающая подсказка
        "width": 130,  # Ширина кнопки
        "height": 40,  # Высота кнопки
    }

    # Настройки строки с полем ввода и кнопкой отправки
    INPUT_ROW = {
        "spacing": 10,  # Отступ между элементами
        "alignment": ft.MainAxisAlignment.SPACE_BETWEEN,  # Распределение пространства между элементами
        "width": 920,  # Общая ширина строки
    }

    # Настройки строки с кнопками управления
    CONTROL_BUTTONS_ROW = {
        "spacing": 20,  # Отступ между кнопками
        "alignment": ft.MainAxisAlignment.CENTER,  # Выравнивание кнопок по центру
    }

    # Настройки колонки с элементами управления
    CONTROLS_COLUMN = {
        "spacing": 20,  # Отступ между элементами
        "horizontal_alignment": ft.CrossAxisAlignment.CENTER,  # Выравнивание по центру по горизонтали
    }

    # Настройки главной колонки приложения
    MAIN_COLUMN = {
        "expand": True,  # Разрешение расширения
        "spacing": 20,  # Отступ между элементами
        "alignment": ft.MainAxisAlignment.CENTER,  # Вертикальное выравнивание по центру
        "horizontal_alignment": ft.CrossAxisAlignment.CENTER,  # Горизонтальное выравнивание по центру
    }

    # Настройки поля поиска модели
    MODEL_SEARCH_FIELD = {
        "width": 400,  # Ширина поля в пикселях
        "border_radius": 8,  # Радиус скругления углов
        "bgcolor": ft.Colors.GREY_900,  # Цвет фона поля
        "border_color": ft.Colors.GREY_700,  # Цвет границы в обычном состоянии
        "color": ft.Colors.WHITE,  # Цвет текста
        "content_padding": 10,  # Внутренние отступы
        "cursor_color": ft.Colors.WHITE,  # Цвет курсора
        "focused_border_color": ft.Colors.BLUE_400,  # Цвет границы при фокусе
        "focused_bgcolor": ft.Colors.GREY_800,  # Цвет фона при фокусе
        "hint_style": ft.TextStyle(  # Стиль текста-подсказки
            color=ft.Colors.GREY_400,  # Цвет текста-подсказки
            size=14,  # Размер шрифта подсказки
        ),
        "prefix_icon": ft.Icons.SEARCH,  # Иконка поиска слева от поля
        "height": 45,  # Высота поля
    }

    # Настройки выпадающего списка выбора модели
    MODEL_DROPDOWN = {
        "width": 400,  # Ширина списка
        "height": 45,  # Высота в закрытом состоянии
        "border_radius": 8,  # Радиус скругления углов
        "bgcolor": ft.Colors.GREY_900,  # Цвет фона
        "border_color": ft.Colors.GREY_700,  # Цвет границы
        "color": ft.Colors.WHITE,  # Цвет текста
        "content_padding": 10,  # Внутренние отступы
        "focused_border_color": ft.Colors.BLUE_400,  # Цвет границы при фокусе
        "focused_bgcolor": ft.Colors.GREY_800,  # Цвет фона при фокусе
    }

    # Настройки колонки с элементами выбора модели
    MODEL_SELECTION_COLUMN = {
        "spacing": 10,  # Отступ между элементами
        "horizontal_alignment": ft.CrossAxisAlignment.CENTER,  # Выравнивание по центру
        "width": 400,  # Ширина колонки
    }

    # Настройки текста отображения баланса
    BALANCE_TEXT = {
        "size": 16,  # Размер шрифта
        "color": ft.Colors.GREEN_400,  # Зеленый цвет для позитивного восприятия
        "weight": ft.FontWeight.BOLD,  # Жирное начертание для акцента
    }

    # Настройки контейнера для отображения баланса
    BALANCE_CONTAINER = {
        "padding": 10,  # Внутренние отступы
        "bgcolor": ft.Colors.GREY_900,  # Цвет фона
        "border_radius": 8,  # Радиус скругления углов
        "border": ft.border.all(1, ft.Colors.GREY_700),  # Тонкая серая граница
    }

    @staticmethod
    def set_window_size(page: ft.Page):
        """
        Установка фиксированного размера окна приложения

        Args:
            page (ft.Page): Объект страницы приложения
        """
        page.window.width = 600  # Фиксированная ширина окна
        page.window.height = 800  # Фиксированная высота окна
        page.window.resizable = False  # Запрет изменения размера пользователем
