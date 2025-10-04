<<<<<<< HEAD
# DTech-49
DigitalTech AI education

В этом репозитории собраны учебные проекты по курсу "Разработка нейросетей"
=======
# Flet Prod — чат-приложение с авторизацией через OpenRouter

Интерактивное десктоп-приложение на **Flet** для общения с моделями через **OpenRouter**.  
Поддерживает первый вход по **API-ключу** (проверка баланса) с авто-генерацией **PIN** и последующие входы по PIN.  
Основной UI (чат, выбор моделей, история, экспорт) остаётся в вашем исходном `main.py`.

---

##  Возможности

- Первый вход: ввод **OpenRouter API Key** → проверка `GET /credits` → авто-генерация 4-значного **PIN**
- Хранение ключа на устройстве, PIN — **только в виде хэша (PBKDF2-HMAC-SHA256 + соль)**
- Повторные входы по PIN; **«Сбросить ключ»** в окне авторизации
- Выбор модели, отправка сообщений, история диалога, экспорт истории
- Логи в файл и консоль
- Совместимость с Flet ≥ **0.25** (используются `ft.Colors` и `ft.Icons`)

---

## Архитектура

```
src/
├─ auth_gate.py        # Точка входа с аутентификацией (логин → запуск вашего main.py/ChatApp)
├─ main.py             # Ваш исходный UI (без изменений)
├─ api/
│  └─ openrouter.py    # Клиент OpenRouter (модели, отправка, баланс)
├─ ui/
│  ├─ components.py    # Компоненты UI (MessageBubble, ModelSelector, LoginCard и др.)
│  └─ styles.py        # Стили и пресеты (Colors/Icons и т.д.)
├─ utils/
│  ├─ cache.py         # Кэширование истории
│  ├─ logger.py        # Логгер (без дублей хендлеров)
│  ├─ analytics.py     # Аналитика (использует cache)
│  └─ monitor.py       # Метрики/производительность
```
**Важно:** запускать следует **`auth_gate.py`** — он показывает логин и затем подключает ваш прежний `main.py`:
- если в `main.py` есть `ChatApp().main(page)` — встроит прямо в окно;
- если есть `main(page)` — вызовет его;
- если в `main.py` только `main()` **без аргументов** — корректно перезапустит процесс `python main.py`,
  передав ключ через переменные окружения.

---

##  Быстрый старт

### 1) Требования
- Python **3.10–3.12** (рекомендовано 3.11)
- ОС: Windows / macOS / Linux

### 2) Установка
```bash
git clone <ваш-репозиторий>
cd Flet_Prod
python -m venv venv
# Windows:
venv\Scripts\activate
# macOS / Linux:
source venv/bin/activate

pip install -r requirements.txt
```

### 3) Запуск
```bash
# Запускаем ТОЛЬКО через auth_gate:
python src/auth_gate.py
```

Первый запуск:
1. Введите **OpenRouter API Key** → приложение проверит баланс.
2. Получите сгенерированный **PIN** (показывается один раз) и сохраните его.
3. Введите PIN для входа.
4. Откроется ваш обычный UI из `main.py`.

Повторные запуски:
- Сразу увидите форму PIN. Есть кнопка **«Сбросить ключ»** для ввода нового API-ключа.

---

##  Хранение данных

- База приложения:
  - **Windows:** `%APPDATA%/Flet_Prod/app_db.json`
  - **macOS/Linux:** `~/.config/Flet_Prod/app_db.json`
- Содержимое:
  - `api_key` — в явном виде (локально на машине пользователя)
  - `pin_hash`, `pin_salt` — хэш PIN (PBKDF2-SHA256, 100k итераций) + соль  
    > Сам PIN **не хранится** и не восстанавливается.
- Экспорт истории: `.../Flet_Prod/exports/`.

---

## ️ Конфигурация

Проект работает **без** `.env`.  
Рекомендуем положить в корень **`.env.example`** (для несекретных параметров):

```env
# .env.example — не храните здесь секреты!
BASE_URL=https://openrouter.ai/api/v1
LOG_LEVEL=INFO
# OPENROUTER_API_KEY=  # НЕ заполняйте: ключ вводится через экран логина
```

Если нужно запускать **напрямую** `main.py` (мимо экрана логина), установите переменную окружения:

```bash
# Windows (PowerShell)
$env:OPENROUTER_API_KEY="sk-or-ваш-ключ"
python src/main.py

# macOS / Linux
export OPENROUTER_API_KEY="sk-or-ваш-ключ"
python src/main.py
```

---

##  Сборка в бинарник (опционально)

```bash
pyinstaller --onefile --name FletProd --add-data "src;src" src/auth_gate.py
# По необходимости добавьте --windowed для GUI на macOS/Windows
```

---

##  Траблшутинг

- **DeprecationWarning про иконки/цвета**  
  Используйте `ft.Icons.*` и `ft.Colors.*` (Flet ≥ 0.25). В проекте это уже учтено.

- **`OPENROUTER_API_KEY is required`**  
  Запускайте через `auth_gate.py` и пройдите логин; либо задайте `OPENROUTER_API_KEY` в окружении.

- **Баланс отображается как `н/д` или строка**  
  Проверьте доступность `GET /credits` и сеть/прокси; в коде предусмотрен мягкий фолбэк для строкового ответа.

- **Потеряли PIN**  
  В окне логина нажмите **«Сбросить ключ»** → введите API-ключ снова → получите новый PIN.

---

##  Git / репозиторные файлы

Добавьте в `.gitignore`:

```
venv/
.env
logs/
exports/
build/
dist/
__pycache__/
*.pyc
```

>>>>>>> 0449dd7 (Initial commit: Flet_auth)
