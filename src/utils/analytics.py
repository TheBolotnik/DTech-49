import time  # Библиотека для работы с временными метками и измерения интервалов
from datetime import datetime  # Библиотека для работы с датой и временем в удобном формате


class Analytics:
    """
    Класс для сбора и анализа данных об использовании приложения.

    Отслеживает различные метрики использования чата:
    - Статистику по моделям
    - Время ответа
    - Использование токенов
    - Длину сообщений
    - Общую длительность сессии
    """

    def __init__(self, cache):
        """
        Инициализация системы аналитики.

        Args:
            cache (ChatCache): Экземпляр класса для работы с базой данных

        Создает необходимые структуры данных для хранения:
        - Времени начала сессии
        - Статистики использования моделей
        - Детальных данных о каждом сообщении
        """
        self.cache = cache
        self.start_time = time.time()
        self.model_usage = {}
        self.session_data = []

        # Загрузка исторических данных из базы
        self._load_historical_data()

    def _load_historical_data(self):
        """
        Загрузка исторических данных из базы данных.
        Обновляет статистику использования моделей и сессионные данные.
        """
        history = self.cache.get_analytics_history()

        for record in history:
            timestamp, model, message_length, response_time, tokens_used = record

            # Обновление статистики моделей
            if model not in self.model_usage:
                self.model_usage[model] = {
                    'count': 0,
                    'tokens': 0
                }
            self.model_usage[model]['count'] += 1
            self.model_usage[model]['tokens'] += tokens_used

            # Добавление в сессионные данные
            self.session_data.append({
                'timestamp': datetime.strptime(timestamp, '%Y-%m-%d %H:%M:%S.%f'),
                'model': model,
                'message_length': message_length,
                'response_time': response_time,
                'tokens_used': tokens_used
            })

    def track_message(self, model: str, message_length: int, response_time: float, tokens_used: int):
        """
        Отслеживание метрик отдельного сообщения.

        Сохраняет подробную информацию о каждом сообщении и обновляет
        общую статистику использования моделей.

        Args:
            model (str): Идентификатор использованной модели
            message_length (int): Длина сообщения в символах
            response_time (float): Время ответа в секундах
            tokens_used (int): Количество использованных токенов
        """
        timestamp = datetime.now()

        # Сохранение в базу данных
        self.cache.save_analytics(timestamp, model, message_length, response_time, tokens_used)

        # Инициализация статистики для новой модели при первом использовании
        if model not in self.model_usage:
            self.model_usage[model] = {
                'count': 0,  # Счетчик использований
                'tokens': 0  # Счетчик токенов
            }

        # Обновление статистики использования модели
        self.model_usage[model]['count'] += 1  # Увеличение счетчика сообщений
        self.model_usage[model]['tokens'] += tokens_used  # Добавление использованных токенов

        # Сохранение подробной информации о сообщении
        self.session_data.append({
            'timestamp': timestamp,  # Время отправки сообщения
            'model': model,  # Использованная модель
            'message_length': message_length,  # Длина сообщения
            'response_time': response_time,  # Время ответа
            'tokens_used': tokens_used  # Количество токенов
        })

    def get_statistics(self) -> dict:
        """
        Получение общей статистики использования.

        Вычисляет и возвращает агрегированные метрики на основе
        собранных данных о сообщениях и использовании моделей.

        Returns:
            dict: Словарь с различными метриками:
                - total_messages: общее количество сообщений
                - total_tokens: общее количество использованных токенов
                - session_duration: длительность сессии в секундах
                - messages_per_minute: среднее количество сообщений в минуту
                - tokens_per_message: среднее количество токенов на сообщение
                - model_usage: статистика использования каждой модели
        """
        # Расчет общей длительности сессии
        total_time = time.time() - self.start_time

        # Подсчет общего количества токенов по всем моделям
        total_tokens = sum(model['tokens'] for model in self.model_usage.values())

        # Подсчет общего количества сообщений по всем моделям
        total_messages = sum(model['count'] for model in self.model_usage.values())

        # Формирование и возврат статистики
        return {
            'total_messages': total_messages,  # Общее количество сообщений
            'total_tokens': total_tokens,  # Общее количество токенов
            'session_duration': total_time,  # Длительность сессии в секундах

            # Расчет среднего количества сообщений в минуту
            # Если сессия только началась (total_time близко к 0),
            # возвращаем 0 чтобы избежать деления на очень маленькое число
            'messages_per_minute': (total_messages * 60) / total_time if total_time > 0 else 0,

            # Расчет среднего количества токенов на сообщение
            # Если сообщений нет, возвращаем 0 чтобы избежать деления на ноль
            'tokens_per_message': total_tokens / total_messages if total_messages > 0 else 0,

            # Полная статистика использования моделей
            'model_usage': self.model_usage
        }

    def export_data(self) -> list:
        """
        Экспорт всех собранных данных сессии.

        Returns:
            list: Список словарей с подробной информацией о каждом сообщении
                 включая временные метки, использованные модели и метрики.
        """
        return self.session_data

    def clear_data(self):
        """
        Очистка всех накопленных данных аналитики.

        Сбрасывает все счетчики и метрики, начиная новую сессию:
        - Очищает статистику использования моделей
        - Очищает историю сообщений
        - Сбрасывает время начала сессии
        """
        self.model_usage.clear()  # Очистка статистики по моделям
        self.session_data.clear()  # Очистка истории сообщений
