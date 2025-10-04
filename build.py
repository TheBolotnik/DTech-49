
import sys  # Для доступа к системным параметрам и функциям
import shutil  # Для операций с файлами и директориями
import subprocess  # Для запуска внешних процессов
from pathlib import Path  # Для удобной работы с путями файловой системы


def build_windows():
    """Сборка исполняемого файла для Windows с помощью PyInstaller"""
    print("Building Windows executable...")

    # Устанавливаем зависимости проекта для Windows из файла requirements.txt
    # sys.executable - путь к текущему интерпретатору Python
    subprocess.run([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])

    # Создаём директорию bin, если она не существует
    # exist_ok=True позволяет не выбрасывать ошибку, если директория уже существует
    bin_dir = Path("bin")
    bin_dir.mkdir(exist_ok=True)

    # Запускаем PyInstaller со следующими параметрами:
    # --onefile: создать один исполняемый файл
    # --windowed: запускать без консольного окна
    # --name: задать имя выходного файла
    # --clean: очистить кэш PyInstaller перед сборкой
    # --noupx: не использовать UPX для сжатия
    # --uac-admin: запрашивать права администратора при запуске
    subprocess.run([
        "pyinstaller",
        "--onefile",
        "--windowed",
        "--name=AI Chat",
        "--clean",
        "--noupx",
        "--uac-admin",
        "src/main.py"
    ])

    # Перемещаем собранный файл в директорию bin
    # Используем try/except для обработки возможных ошибок при перемещении
    try:
        shutil.move("dist/AI Chat.exe", "bin/AIChat.exe")
        print("Windows build completed! Executable location: bin/AIChat.exe")
    except:
        print("Windows build completed! Executable location: dist/AI Chat.exe")


def build_linux():
    """Сборка исполняемого файла для Linux с помощью PyInstaller"""
    print("Building Linux executable...")

    # Устанавливаем зависимости проекта для Linux
    subprocess.run([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])

    # Создаём директорию bin, если она не существует
    bin_dir = Path("bin")
    bin_dir.mkdir(exist_ok=True)

    # Запускаем PyInstaller для Linux со следующими параметрами:
    # --onefile: создать один исполняемый файл
    # --windowed: запускать без консольного окна
    # --icon: указать иконку приложения
    # --name: задать имя выходного файла
    subprocess.run([
        "pyinstaller",
        "--onefile",
        "--windowed",
        "--icon=assets/icon.ico",
        "--name=aichat",
        "src/main.py"
    ])

    # Перемещаем собранный файл в директорию bin
    try:
        shutil.move("dist/aichat", "bin/aichat")
        print("Linux build completed! Executable location: bin/aichat")
    except:
        print("Linux build completed! Executable location: dist/aichat")


def main():
    """Основная функция сборки

    Определяет операционную систему и запускает соответствующую функцию сборки
    """
    # Проверяем тип операционной системы
    if sys.platform.startswith('win'):  # Если Windows
        build_windows()
    elif sys.platform.startswith('linux'):  # Если Linux
        build_linux()
    else:  # Если другая ОС
        print("Unsupported platform")


# Точка входа в скрипт
# Если скрипт запущен напрямую (не импортирован как модуль),
# то запускаем основную функцию
if __name__ == "__main__":
    main()
