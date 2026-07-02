# Используем официальный легковесный образ Python
FROM python:3.12-slim

# Устанавливаем переменные окружения:
# PYTHONDONTWRITEBYTECODE 1 — запрещает Python записывать файлы .pyc на диск
# PYTHONUNBUFFERED 1 — гарантирует, что вывод логов будет мгновенным и не будет буферизироваться
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Устанавливаем рабочую директорию внутри контейнера
WORKDIR /app/backend

# Устанавливаем системные зависимости, необходимые для компиляции драйверов БД (psycopg2)
# После установки удаляем кэш apt, чтобы образ весил меньше
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Копируем файл зависимостей
COPY requirements.txt .

# Обновляем pip и устанавливаем зависимости проекта
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Копируем весь код проекта в контейнер
COPY . .

# Открываем порт 8000 (стандартный для Django)
EXPOSE 8000

# Команда для запуска проекта по умолчанию (используем gunicorn)
# Мы указываем путь к wsgi: config.wsgi:application
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "config.wsgi:application"]