// Импорт основных виджетов Flutter
import 'package:flutter/material.dart';
// Импорт пакета для работы с .env файлами
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Импорт пакета для локализации приложения
import 'package:flutter_localizations/flutter_localizations.dart';
// Импорт пакета для работы с провайдерами состояния
import 'package:provider/provider.dart';
// Импорт кастомного провайдера для управления состоянием чата
import 'providers/chat_provider.dart';
// Импорт провайдера аутентификации
import 'auth/auth_provider.dart';
import 'auth/auth_state.dart';
import 'auth/auth_service.dart';
import 'auth/credentials_repository.dart';
import 'services/secure_keystore.dart';
import 'services/database_service.dart';
// Импорт экранов
import 'screens/chat_screen.dart';
import 'screens/api_key_screen.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/pin_login_screen.dart';

// Виджет для обработки и отлова ошибок в приложении
class ErrorBoundaryWidget extends StatelessWidget {
  // Дочерний виджет, который будет обернут в обработчик ошибок
  final Widget child;

  // Конструктор с обязательным параметром child
  const ErrorBoundaryWidget({super.key, required this.child});

  // Метод построения виджета
  @override
  Widget build(BuildContext context) {
    // Используем Builder для создания нового контекста
    return Builder(
      // Функция построения виджета с обработкой ошибок
      builder: (context) {
        // Пытаемся построить дочерний виджет
        try {
          // Возвращаем дочерний виджет, если ошибок нет
          return child;
          // Ловим и обрабатываем ошибки
        } catch (error, stackTrace) {
          // Логируем ошибку в консоль
          debugPrint('Error in ErrorBoundaryWidget: $error');
          // Логируем стек вызовов для отладки
          debugPrint('Stack trace: $stackTrace');
          // Возвращаем MaterialApp с экраном ошибки
          return MaterialApp(
            // Основной экран приложения
            home: Scaffold(
              // Красный фон для экрана ошибки
              backgroundColor: Colors.red,
              // Центрируем содержимое
              body: Center(
                // Добавляем отступы
                child: Padding(
                  // Отступы 16 пикселей со всех сторон
                  padding: const EdgeInsets.all(16.0),
                  // Текст с описанием ошибки
                  child: Text(
                    // Отображаем текст ошибки
                    'Error: $error',
                    // Белый цвет текста
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

// Основная точка входа в приложение
void main() async {
  try {
    // Инициализация Flutter биндингов
    WidgetsFlutterBinding.ensureInitialized();

    // Настройка обработки ошибок Flutter
    FlutterError.onError = (FlutterErrorDetails details) {
      // Отображение ошибки
      FlutterError.presentError(details);
      // Логирование ошибки
      debugPrint('Flutter error: ${details.exception}');
      // Логирование стека вызовов
      debugPrint('Stack trace: ${details.stack}');
    };

    // Загрузка переменных окружения из .env файла
    // NOTE: .env больше не содержит API ключей - только настройки приложения
    await dotenv.load(fileName: ".env");
    debugPrint('Environment configuration loaded');

    // Запуск приложения с обработчиком ошибок
    runApp(const ErrorBoundaryWidget(child: MyApp()));
  } catch (e, stackTrace) {
    // Логирование ошибки запуска приложения
    debugPrint('Error starting app: $e');
    // Логирование стека вызовов
    debugPrint('Stack trace: $stackTrace');
    // Запуск приложения с экраном ошибки
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error starting app: $e',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Виджет навигации на основе состояния аутентификации
class AuthNavigator extends StatefulWidget {
  const AuthNavigator({super.key});

  @override
  State<AuthNavigator> createState() => _AuthNavigatorState();
}

class _AuthNavigatorState extends State<AuthNavigator> {
  @override
  void initState() {
    super.initState();
    // Вызов bootstrap при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Слушаем изменения состояния аутентификации
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Навигация по AuthState с использованием pattern matching
        final state = authProvider.state;
        if (state is AuthNoKey) {
          // Экран ввода API ключа
          return const ApiKeyScreen();
        } else if (state is AuthCheckingKey) {
          // Экран загрузки при проверке ключа
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (state is AuthPinSetup) {
          // Экран настройки PIN
          return const PinSetupScreen();
        } else if (state is AuthPinRequired) {
          // Экран входа по PIN
          return const PinLoginScreen();
        } else if (state is AuthAuthorized) {
          // Главный экран чата
          return const ChatScreen();
        } else if (state is AuthError) {
          // Экран ошибки
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Ошибка: ${state.message}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<AuthProvider>().reset();
                      },
                      child: const Text('Начать заново'),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          // Fallback
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
    );
  }
}

// Основной виджет приложения
class MyApp extends StatelessWidget {
  // Конструктор с ключом
  const MyApp({super.key});

  // Метод построения виджета
  @override
  Widget build(BuildContext context) {
    // Используем MultiProvider для управления несколькими провайдерами
    return MultiProvider(
      providers: [
        // Создаем DatabaseService как Provider
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
        // Создаем SecureKeyStore как Provider
        Provider<SecureKeyStore>(
          create: (_) => SecureKeyStore(),
        ),
        // Создаем CredentialsRepository на основе DatabaseService и SecureKeyStore
        ProxyProvider2<DatabaseService, SecureKeyStore, CredentialsRepository>(
          update: (_, db, keystore, __) => CredentialsRepository(db, keystore),
        ),
        // Провайдер аутентификации - зависит от CredentialsRepository
        ChangeNotifierProxyProvider<CredentialsRepository, AuthProvider>(
          create: (context) {
            final repo =
                Provider.of<CredentialsRepository>(context, listen: false);
            final authService = AuthService(repo);
            return AuthProvider(authService);
          },
          update: (_, repo, previous) {
            if (previous == null) {
              final authService = AuthService(repo);
              return AuthProvider(authService);
            }
            return previous;
          },
        ),
        // Провайдер чата - зависит от CredentialsRepository
        ChangeNotifierProxyProvider<CredentialsRepository, ChatProvider>(
          create: (context) {
            final repo =
                Provider.of<CredentialsRepository>(context, listen: false);
            return ChatProvider(repo);
          },
          update: (_, repo, previous) {
            if (previous == null) {
              return ChatProvider(repo);
            }
            // Обновляем репозиторий в существующем провайдере
            previous.attachCredentialsRepo(repo);
            return previous;
          },
        ),
      ],
      // Основной виджет MaterialApp
      child: MaterialApp(
        // Настройка поведения прокрутки
        builder: (context, child) {
          return ScrollConfiguration(
            behavior: ScrollBehavior(),
            child: child!,
          );
        },
        // Заголовок приложения
        title: 'AI Chat',
        // Скрытие баннера debug
        debugShowCheckedModeBanner: false,
        // Установка локали по умолчанию (русский)
        locale: const Locale('ru', 'RU'),
        // Поддерживаемые локали
        supportedLocales: const [
          Locale('ru', 'RU'), // Русский
          Locale('en', 'US'), // Английский (США)
        ],
        // Делегаты для локализации
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate, // Локализация Material виджетов
          GlobalWidgetsLocalizations.delegate, // Локализация базовых виджетов
          GlobalCupertinoLocalizations
              .delegate, // Локализация Cupertino виджетов
        ],
        // Настройка темы приложения
        theme: ThemeData(
          // Цветовая схема на основе синего цвета
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue, // Основной цвет
            brightness: Brightness.dark, // Темная тема
          ),
          // Использование Material 3
          useMaterial3: true,
          // Цвет фона Scaffold
          scaffoldBackgroundColor: const Color(0xFF1E1E1E),
          // Настройка темы AppBar
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF262626), // Цвет фона
            foregroundColor: Colors.white, // Цвет текста
          ),
          // Настройка темы диалогов
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF333333), // Цвет фона
            titleTextStyle: TextStyle(
              color: Colors.white, // Цвет заголовка
              fontSize: 20, // Размер шрифта
              fontWeight: FontWeight.bold, // Жирный шрифт
              fontFamily: 'Roboto', // Шрифт
            ),
            contentTextStyle: TextStyle(
              color: Colors.white70, // Цвет текста
              fontSize: 16, // Размер шрифта
              fontFamily: 'Roboto', // Шрифт
            ),
          ),
          // Настройка текстовой темы
          textTheme: const TextTheme(
            bodyLarge: TextStyle(
              fontFamily: 'Roboto', // Шрифт
              fontSize: 16, // Размер шрифта
              color: Colors.white, // Цвет текста
            ),
            bodyMedium: TextStyle(
              fontFamily: 'Roboto', // Шрифт
              fontSize: 14, // Размер шрифта
              color: Colors.white, // Цвет текста
            ),
          ),
          // Настройка темы кнопок
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white, // Цвет текста
              textStyle: const TextStyle(
                fontFamily: 'Roboto', // Шрифт
                fontSize: 14, // Размер шрифта
              ),
            ),
          ),
          // Настройка темы текстовых кнопок
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white, // Цвет текста
              textStyle: const TextStyle(
                fontFamily: 'Roboto', // Шрифт
                fontSize: 14, // Размер шрифта
              ),
            ),
          ),
        ),
        // Основной экран с навигацией по AuthState
        home: const AuthNavigator(),
      ),
    );
  }
}
