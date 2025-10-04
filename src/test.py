try:
    from api import OpenRouterClient
    from ui import MessageBubble, AppStyles
    from utils import ChatCache, AppLogger

    print("Все импорты работают корректно!")
except ImportError as e:
    print(f"Ошибка импорта: {e}")