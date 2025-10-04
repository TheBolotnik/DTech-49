import psutil  # Библиотека для мониторинга системных ресурсов (CPU, память, потоки)
import time  # Библиотека для работы с временными метками и измерения интервалов
from datetime import datetime  # Библиотека для работы с датой и временем
import threading  # Библиотека для работы с потоками


class PerformanceMonitor:
    """
    Класс для мониторинга производительности приложения.

    Отслеживает и анализирует:
    - Использование CPU
    - Использование памяти
    - Количество активных потоков
    - Время работы приложения
    - Общее состояние системы
    """

    def __init__(self):
        """
        Инициализация системы мониторинга производительности.

        Настраивает:
        - Время начала мониторинга
        - Хранилище истории метрик
        - Отслеживание текущего процесса
        - Пороговые значения для метрик
        """
        self.start_time = time.time()  # Сохранение времени запуска для расчета uptime
        self.metrics_history = []  # Список для хранения истории метрик
        self.process = psutil.Process()  # Получение объекта текущего процесса

        # Пороговые значения для определения проблем с производительностью
        self.thresholds = {
            'cpu_percent': 80.0,  # Максимально допустимый процент использования CPU
            'memory_percent': 75.0,  # Максимально допустимый процент использования памяти
            'thread_count': 50  # Максимально допустимое количество потоков
        }

    def get_metrics(self) -> dict:
        """
        Получение текущих метрик производительности.

        Returns:
            dict: Словарь с текущими метриками:
                - timestamp: время замера
                - cpu_percent: процент использования CPU
                - memory_percent: процент использования памяти
                - thread_count: количество активных потоков
                - uptime: время работы приложения

        Note:
            В случае ошибки возвращает словарь с ключом 'error'
        """
        try:
            # Сбор текущих метрик производительности
            metrics = {
                'timestamp': datetime.now(),  # Время замера
                'cpu_percent': self.process.cpu_percent(),  # Загрузка CPU
                'memory_percent': self.process.memory_percent(),  # Использование памяти
                'thread_count': len(self.process.threads()),  # Количество потоков
                'uptime': time.time() - self.start_time  # Время работы
            }

            # Сохранение метрик в историю
            self.metrics_history.append(metrics)

            # Ограничение размера истории последними 1000 записями
            if len(self.metrics_history) > 1000:
                self.metrics_history.pop(0)  # Удаление самой старой записи

            return metrics

        except Exception as e:
            # Возврат информации об ошибке при сборе метрик
            return {
                'error': str(e),
                'timestamp': datetime.now()
            }

    def check_health(self) -> dict:
        """
        Проверка состояния системы на основе пороговых значений.

        Анализирует текущие метрики и сравнивает их с пороговыми значениями
        для определения потенциальных проблем с производительностью.

        Returns:
            dict: Словарь с информацией о состоянии системы:
                - status: 'healthy', 'warning' или 'error'
                - warnings: список предупреждений (если есть)
                - timestamp: время проверки
        """
        metrics = self.get_metrics()  # Получение текущих метрик

        # Проверка на наличие ошибок при сборе метрик
        if 'error' in metrics:
            return {'status': 'error', 'error': metrics['error']}

        # Инициализация отчета о состоянии
        health_status = {
            'status': 'healthy',  # Начальный статус - здоровый
            'warnings': [],  # Список для хранения предупреждений
            'timestamp': metrics['timestamp']  # Время проверки
        }

        # Проверка загрузки CPU
        if metrics['cpu_percent'] > self.thresholds['cpu_percent']:
            health_status['warnings'].append(
                f"High CPU usage: {metrics['cpu_percent']}%"
            )
            health_status['status'] = 'warning'

        # Проверка использования памяти    
        if metrics['memory_percent'] > self.thresholds['memory_percent']:
            health_status['warnings'].append(
                f"High memory usage: {metrics['memory_percent']}%"
            )
            health_status['status'] = 'warning'

        # Проверка количества потоков    
        if metrics['thread_count'] > self.thresholds['thread_count']:
            health_status['warnings'].append(
                f"High thread count: {metrics['thread_count']}"
            )
            health_status['status'] = 'warning'

        return health_status

    def get_average_metrics(self) -> dict:
        """
        Расчет средних показателей за всю историю наблюдений.

        Вычисляет средние значения для:
        - Использования CPU
        - Использования памяти
        - Количества потоков

        Returns:
            dict: Словарь со средними значениями метрик или сообщением об ошибке
        """
        # Проверка наличия данных для анализа
        if not self.metrics_history:
            return {"error": "No metrics available"}

        # Расчет средних значений по всей истории метрик
        avg_metrics = {
            'avg_cpu': sum(m['cpu_percent'] for m in self.metrics_history) / len(self.metrics_history),
            'avg_memory': sum(m['memory_percent'] for m in self.metrics_history) / len(self.metrics_history),
            'avg_threads': sum(m['thread_count'] for m in self.metrics_history) / len(self.metrics_history),
            'samples_count': len(self.metrics_history)  # Количество проанализированных замеров
        }

        return avg_metrics

    def log_metrics(self, logger) -> None:
        """
        Логирование текущих метрик и состояния системы.

        Записывает в лог:
        - Текущие значения метрик производительности
        - Предупреждения о превышении пороговых значений

        Args:
            logger: Объект логгера для записи информации
        """
        metrics = self.get_metrics()  # Получение текущих метрик
        health = self.check_health()  # Проверка состояния системы

        # Логирование текущих метрик производительности
        if 'error' not in metrics:
            logger.info(
                f"Performance metrics - "
                f"CPU: {metrics['cpu_percent']:.1f}%, "
                f"Memory: {metrics['memory_percent']:.1f}%, "
                f"Threads: {metrics['thread_count']}, "
                f"Uptime: {metrics['uptime']:.0f}s"
            )

        # Логирование предупреждений при проблемах с производительностью
        if health['status'] == 'warning':
            for warning in health['warnings']:
                logger.warning(f"Performance warning: {warning}")

