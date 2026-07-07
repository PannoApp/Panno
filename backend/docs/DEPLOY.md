# Деплой бэкенда Panno на сервер (185.129.51.40)

Пошаговая инструкция для тестового/staging-деплоя через Docker.
Режим: `DEBUG=True` — OTP-коды идут в логи, SMS/Telegram не настраиваются.
Раздел «Переход на настоящий production» — в самом конце.

---

## ⚠️ Шаг 0. Безопасность — сделай это первым

Пароль от сервера был передан в переписке, считай его скомпрометированным.
**После первого входа поменяй пароль root** (команда `passwd` на сервере).
Ещё лучше — настрой вход по SSH-ключу (в конце файла).

---

## Что нам понадобится

- Твой компьютер (Windows, PowerShell) — отсюда подключаемся и копируем файлы.
- Сервер `185.129.51.40`, логин `root`.
- 3 новых файла, которые уже лежат в проекте:
  `backend/docker-compose.prod.yml`, `backend/.env.prod.example`, `backend/docs/DEPLOY.md`.

Схема: код заливаем на сервер через **git**, а два секретных файла
(`.env` и `firebase-credentials.json`, они не в git) — отдельно через **scp**.

---

## ЧАСТЬ A. На твоём компьютере — отправить файлы деплоя в git

Открой PowerShell в папке проекта `Panno` и выполни:

```powershell
git add backend/docker-compose.prod.yml backend/.env.prod.example backend/docs/DEPLOY.md
git commit -m "chore: add production docker-compose and deploy guide"
git push origin main
```

> Если работаешь не в `main`, а в отдельной ветке — запушь её и потом клонируй эту же ветку на сервере.

---

## ЧАСТЬ B. На сервере — установить Docker и запустить

### B1. Подключиться по SSH

В PowerShell на своём компьютере:

```powershell
ssh root@185.129.51.40
```

Первый раз спросит `yes/no` (набери `yes`), затем пароль (при вводе он не отображается — это нормально).

### B2. Проверить операционную систему

```bash
cat /etc/os-release
```

Если увидишь `Ubuntu` или `Debian` — отлично, инструкция ниже для них.
Если это не Linux (например, Windows) — напиши мне, дам отдельную инструкцию.

### B3. Поменять пароль root (безопасность)

```bash
passwd
```

Введи новый надёжный пароль дважды.

### B4. Установить Docker

```bash
curl -fsSL https://get.docker.com | sh
```

Проверь, что всё встало:

```bash
docker --version
docker compose version
```

Обе команды должны показать версии без ошибок.

### B5. Скачать код проекта

Репозиторий приватный, поэтому GitHub попросит логин и токен.

```bash
cd /root
git clone https://github.com/PannoApp/Panno.git
```

- **Username:** твой логин GitHub.
- **Password:** НЕ обычный пароль, а **Personal Access Token**.
  Создать: GitHub → Settings → Developer settings → Personal access tokens →
  Tokens (classic) → Generate new token → отметить `repo` → скопировать.

После клонирования переходим в папку бэкенда:

```bash
cd /root/Panno/backend
```

> Если пушил в отдельную ветку — переключись: `git checkout имя-ветки`.

### B6. Создать файл .env из шаблона

```bash
cp .env.prod.example .env
nano .env
```

В редакторе `nano` поменяй все значения с `CHANGE_ME`:
- `SECRET_KEY` — любая длинная случайная строка;
- `POSTGRES_PASSWORD` — пароль базы;
- `AWS_SECRET_ACCESS_KEY` — пароль MinIO.

Сохрани: `Ctrl+O`, `Enter`, потом выйди: `Ctrl+X`.

---

## ЧАСТЬ C. Скопировать секретный файл Firebase

`firebase-credentials.json` **не хранится в git**. Скопируй его со своего компьютера.
Открой **новое** окно PowerShell на своём компьютере (НЕ то, где ssh) и выполни из папки `Panno`:

```powershell
scp backend/firebase-credentials.json root@185.129.51.40:/root/Panno/backend/
```

> Если этого файла у тебя нет — ничего страшного для теста. Тогда в `.env` можно
> оставить путь как есть, пуши всё равно сейчас не используются. Но если файла нет,
> лучше заранее проверь, что приложение стартует (см. логи в C2 ниже).

---

## ЧАСТЬ D. Запуск

Вернись в SSH-окно (сервер, папка `/root/Panno/backend`).

### D1. Собрать и запустить все контейнеры

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

Первая сборка займёт 3–7 минут (скачивает Python, ffmpeg, зависимости).
Флаг `-d` — запуск в фоне.

### D2. Проверить, что всё поднялось

```bash
docker compose -f docker-compose.prod.yml ps
```

Все сервисы должны быть `Up` (у `db`, `redis`, `minio` — `healthy`).
`minio_init` (createbuckets) отработает и станет `Exited (0)` — это нормально.

Смотрим логи backend (тут же увидишь OTP-коды при входе):

```bash
docker compose -f docker-compose.prod.yml logs -f backend
```

Выйти из просмотра логов — `Ctrl+C` (контейнер продолжит работать).

### D3. Создать администратора для админки

```bash
docker compose -f docker-compose.prod.yml exec backend python manage.py createsuperuser
```

Введи телефон/логин и пароль. Потом сможешь зайти в админку.

### D4. Открыть порты в файрволе

Если на сервере включён `ufw`:

```bash
ufw allow OpenSSH
ufw allow 8000/tcp
ufw allow 9000/tcp
ufw --force enable
ufw status
```

> Порт `9001` (веб-консоль MinIO) наружу лучше **не** открывать — оставь закрытым.
> Также проверь панель управления у хостинга: там может быть свой сетевой файрвол,
> где тоже нужно разрешить порты 8000 и 9000.

---

## ЧАСТЬ E. Проверка, что всё работает

С любого браузера/телефона открой:

- **API документация (Swagger):** http://185.129.51.40:8000/api/docs/
- **Админка:** http://185.129.51.40:8000/admin/
- **MinIO консоль (только для тебя):** доступна на сервере, наружу закрыта.

Проверка OTP-входа:
1. Приложение (или Swagger) отправляет запрос на вход по номеру телефона.
2. В логах backend появится блок:
   ```
   ==============================
   SMS DEV MODE
   Phone: +7...
   OTP: 1234
   ==============================
   ```
3. Этот код вводишь в приложении.

Смотреть код в реальном времени:

```bash
docker compose -f docker-compose.prod.yml logs -f backend
```

---

## ЧАСТЬ F. Настроить мобильное приложение

В приложении укажи базовый адрес API:

```
http://185.129.51.40:8000/api/v1/
```

⚠️ Это **http** (без шифрования). На iOS по умолчанию незашифрованные запросы
блокируются (App Transport Security). Для теста нужно добавить исключение в
`ios/Runner/Info.plist` (временно, до появления домена+HTTPS). Напиши — подскажу,
какой ключ добавить.

---

## Шпаргалка по управлению

Все команды выполняются на сервере из папки `/root/Panno/backend`:

```bash
# Статус контейнеров
docker compose -f docker-compose.prod.yml ps

# Логи всех сервисов / только backend / только worker
docker compose -f docker-compose.prod.yml logs -f
docker compose -f docker-compose.prod.yml logs -f backend
docker compose -f docker-compose.prod.yml logs -f worker

# Перезапустить всё / один сервис
docker compose -f docker-compose.prod.yml restart
docker compose -f docker-compose.prod.yml restart backend

# Остановить всё (данные в БД и MinIO сохранятся — они в volumes)
docker compose -f docker-compose.prod.yml down

# Обновить код после git push (на сервере):
git pull
docker compose -f docker-compose.prod.yml up -d --build

# Django-команды внутри контейнера
docker compose -f docker-compose.prod.yml exec backend python manage.py migrate
docker compose -f docker-compose.prod.yml exec backend python manage.py createsuperuser
docker compose -f docker-compose.prod.yml exec backend python manage.py shell
```

---

## Настроить вход по SSH-ключу (рекомендуется)

На своём компьютере (PowerShell):

```powershell
ssh-keygen -t ed25519        # Enter на все вопросы, если ключа ещё нет
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@185.129.51.40 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

После этого вход будет без пароля. Отключение входа по паролю — отдельный шаг,
подскажу при желании.

---

## Переход на настоящий production (когда появятся домен и SMS)

Сейчас сервер работает в тестовом режиме (`DEBUG=True`). Перед реальным запуском:

1. **Купить домен** и направить его A-записью на `185.129.51.40`.
2. **Подключить SMS-провайдера** — заполнить `SMS_PROVIDER_URL`, `SMS_LOGIN`,
   `SMS_PASSWORD` в `.env` (без этого пользователи не получат коды по SMS).
3. **Переключить настройки** в `.env`:
   ```
   DJANGO_SETTINGS_MODULE=config.settings.prod
   DEBUG=False
   ALLOWED_HOSTS=твой-домен.kz
   CORS_ALLOWED_ORIGINS=https://твой-домен.kz
   ```
   ⚠️ В режиме `prod` файл `config/settings/prod.py` требует ещё и Telegram-переменные
   (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `TELEGRAM_WEBHOOK_SECRET`) — иначе сервер
   не стартует. Раз Telegram не нужен, эту проверку надо будет убрать в `prod.py`
   (по плану из `docs/telegram_removal.md`). Напиши — сделаю аккуратно.
4. **Добавить HTTPS** — поднять nginx + бесплатный сертификат Let's Encrypt
   перед backend. Это отдельная настройка, помогу когда дойдём.
5. Обновить адрес API в приложении на `https://твой-домен.kz/api/v1/`.
