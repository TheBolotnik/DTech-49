// Импорт основных классов Flutter
import 'package:flutter/foundation.dart';

// Сервис для сбора и анализа статистики использования чата
class AnalyticsService {
  // Единственный экземпляр класса (Singleton)
  static final AnalyticsService _instance = AnalyticsService._internal();
  // Время начала сессии
  final DateTime _startTime;
  // Статистика использования моделей
  final Map<String, Map<String, int>> _modelUsage = {};
  // Данные о сообщениях в текущей сессии
  final List<Map<String, dynamic>> _sessionData = [];

  // Фабричный метод для получения экземпляра
  factory AnalyticsService() {
    return _instance;
  }

  // Приватный конструктор для реализации Singleton
  AnalyticsService._internal() : _startTime = DateTime.now();

  // Метод для отслеживания отправленного сообщения
  void trackMessage({
    required String model, // Используемая модель
    required int messageLength, // Длина сообщения
    required double responseTime, // Время ответа
    required int tokensUsed, // Использовано токенов
  }) {
    try {
      // Инициализация статистики для модели, если она еще не существует
      _modelUsage[model] ??= {
        'count': 0, // Счетчик сообщений
        'tokens': 0, // Счетчик токенов
      };

      // Обновление счетчиков использования модели
      _modelUsage[model]!['count'] = (_modelUsage[model]!['count'] ?? 0) + 1;
      _modelUsage[model]!['tokens'] =
          (_modelUsage[model]!['tokens'] ?? 0) + tokensUsed;

      // Сохранение детальной информации о сообщении
      _sessionData.add({
        'timestamp': DateTime.now().toIso8601String(),
        'model': model,
        'message_length': messageLength,
        'response_time': responseTime,
        'tokens_used': tokensUsed,
      });
    } catch (e) {
      debugPrint('Error tracking message: $e');
    }
  }

  // Метод получения общей статистики
  Map<String, dynamic> getStatistics() {
    try {
      final now = DateTime.now();
      final sessionDuration = now.difference(_startTime).inSeconds;

      // Подсчет общего количества сообщений и токенов
      int totalMessages = 0;
      int totalTokens = 0;

      for (final modelStats in _modelUsage.values) {
        totalMessages += modelStats['count'] ?? 0;
        totalTokens += modelStats['tokens'] ?? 0;
      }

      // Расчет средних показателей
      final messagesPerMinute =
          sessionDuration > 0 ? (totalMessages * 60) / sessionDuration : 0.0;

      final tokensPerMessage =
          totalMessages > 0 ? totalTokens / totalMessages : 0.0;

      return {
        'total_messages': totalMessages, // Общее количество сообщений
        'total_tokens': totalTokens, // Общее количество токенов
        'session_duration': sessionDuration, // Длительность сессии в секундах
        'messages_per_minute': messagesPerMinute, // Сообщений в минуту
        'tokens_per_message':
            tokensPerMessage, // Среднее количество токенов на сообщение
        'model_usage': _modelUsage, // Статистика использования моделей
        'start_time': _startTime.toIso8601String(), // Время начала сессии
      };
    } catch (e) {
      debugPrint('Error getting statistics: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  // Метод экспорта данных текущей сессии
  List<Map<String, dynamic>> exportSessionData() {
    return List.from(_sessionData);
  }

  // Метод очистки всех данных
  void clearData() {
    _modelUsage.clear();
    _sessionData.clear();
  }

  // Метод анализа эффективности использования моделей
  Map<String, double> getModelEfficiency() {
    final efficiency = <String, double>{};

    for (final entry in _modelUsage.entries) {
      final modelId = entry.key;
      final stats = entry.value;
      final messageCount = stats['count'] ?? 0;
      final tokensUsed = stats['tokens'] ?? 0;

      // Рассчитываем эффективность как среднее количество токенов на сообщение
      if (messageCount > 0) {
        efficiency[modelId] = tokensUsed / messageCount;
      }
    }

    return efficiency;
  }

  // Метод получения статистики по времени ответа
  Map<String, dynamic> getResponseTimeStats() {
    if (_sessionData.isEmpty) return {};

    final responseTimes =
        _sessionData.map((data) => data['response_time'] as double).toList();

    responseTimes.sort();
    final count = responseTimes.length;

    return {
      'average':
          responseTimes.reduce((a, b) => a + b) / count, // Среднее время ответа
      'median': count.isOdd
          ? responseTimes[count ~/ 2] // Медиана для нечетного количества
          : (responseTimes[(count - 1) ~/ 2] + responseTimes[count ~/ 2]) /
              2, // Медиана для четного
      'min': responseTimes.first, // Минимальное время ответа
      'max': responseTimes.last, // Максимальное время ответа
    };
  }

  // Метод анализа статистики по длине сообщений
  Map<String, dynamic> getMessageLengthStats() {
    if (_sessionData.isEmpty) return {};

    final lengths =
        _sessionData.map((data) => data['message_length'] as int).toList();

    final count = lengths.length;
    final total = lengths.reduce((a, b) => a + b);

    return {
      'average_length': total / count, // Средняя длина сообщения
      'total_characters': total, // Общее количество символов
      'message_count': count, // Количество сообщений
    };
  }
}
