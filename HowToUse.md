# HowToUse — локальная разработка Piligrim

Здесь всё что нужно чтобы поднять проект с нуля и запустить Flutter на реальном устройстве.

---

## Требования

| Инструмент | Версия |
|---|---|
| Flutter | 3.41+ |
| Docker + Docker Compose | любая актуальная |
| Android device / iOS | с включённым USB debugging |
| adb | входит в Android SDK |

---

## 1. Клонируй репо

```bash
git clone <repo-url>
cd Panno
```

---

## 2. Подними бэкенд

```bash
cd backend
cp .env.example .env
```

Открой `.env` и **обязательно измени**:
- `POSTGRES_PASSWORD` — любой пароль
- `ALLOWED_HOSTS` — добавь свой локальный IP (см. ниже как узнать)

Узнать свой IP:
```bash
# macOS
ipconfig getifaddr en0

# Linux
ip a | grep "inet " | grep -v 127
```

Добавь IP в `.env`:
```
ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0,backend,10.0.2.2,10.120.X.X
```

Запусти все сервисы:
```bash
docker compose up --build
```

Проверь что всё поднялось:
```bash
docker compose ps
```

Все контейнеры должны быть `Up`:
- `postgres_db` — база данных
- `redis_cache` — кэш и очереди
- `django_backend` — API на порту 8000
- `celery_worker` — фоновые задачи
- `celery_beat` — планировщик задач

Применить миграции (только первый раз или после изменений моделей):
```bash
docker compose exec backend python manage.py migrate
```

Создать суперпользователя для Django Admin:
```bash
docker compose exec backend python manage.py createsuperuser
```

### Полезные ссылки (после запуска)

| Что | URL |
|---|---|
| Django Admin | http://localhost:8000/admin/ |
| Swagger API docs | http://localhost:8000/api/docs/ |
| ReDoc | http://localhost:8000/api/redoc/ |

---

## 3. Настрой Flutter

### Зависимости

```bash
# из корня репо (не из backend/)
flutter pub get
```

### Конфигурационные файлы

В корне проекта реально лежат только два `.env.*.json` файла:

| Файл | В git | Для чего |
|---|---|---|
| `.env.server.json` | закоммичен | Единственный сейчас реально задеплоенный бэкенд — **стейдж** (`185.98.7.12`). Прод (`piligrim.kz`) в коде — заглушка на будущее, деплоя туда пока нет. |
| `.env.device.json` | в `.gitignore`, у каждого свой | Локальный бэкенд (`docker compose`, см. раздел 2) на физическом устройстве. Заведи свой файл с `BASE_URL`/`MEDIA_ORIGIN` на свой локальный IP или `localhost` через `adb reverse`. |

> ⚠️ **`.env.server.json` — это реальный стейдж, а не песочница.** Он использует тот же самый `REMARKED_API_TOKEN`/`REMARKED_POINT_ID`, что и продовая интеграция с Remarked (см. `backend/docs/remarked.md`) — отдельного тестового аккаунта в Remarked нет. Бронь, отправленная через `.env.server.json`, видна реальному персоналу зала в их CRM, и они могут её подтвердить как настоящую — гость (твой тестовый телефон) получит настоящий push. Если нужно погонять бронирования без риска зацепить Remarked — см. раздел «Тестирование без Remarked» ниже.

Файлов `.env.android.json` и `.env.ios.json` в проекте нет — для эмулятора/симулятора см. разделы 5 и 6 ниже.

---

## 4. Запуск на физическом Android-устройстве (USB)

### 4.1 Включи USB debugging на телефоне

Настройки → О телефоне → нажми 7 раз на «Номер сборки» → Настройки разработчика → USB-отладка: ВКЛ

### 4.2 Пробрось порт через USB

```bash
adb devices          # убедись что телефон виден
adb reverse tcp:8000 tcp:8000
```

> `adb reverse` создаёт туннель: телефон → `localhost:8000` → твой Mac:8000.
> Нужно повторять после каждого переподключения кабеля.

### 4.3 Запусти Flutter

```bash
flutter run --dart-define-from-file=.env.device.json
```

### 4.4 Горячая перезагрузка

Пока `flutter run` запущен:
- `r` — hot reload (обновить UI без перезапуска)
- `R` — hot restart (полный перезапуск)
- `q` — выход

---

## 5. Запуск на эмуляторе

Отдельного `.env.android.json` нет — выбери, к какому бэкенду обращаться:

```bash
# Запусти эмулятор через Android Studio или AVD Manager

# Вариант А — против стейджа (реальный Remarked, см. предупреждение выше)
flutter run --dart-define-from-file=.env.server.json

# Вариант Б — против локального docker-compose бэкенда (раздел 2).
# Эмулятор обращается к хосту через 10.0.2.2, а не localhost.
flutter run --dart-define=BASE_URL=http://10.0.2.2:8000/api/v1 \
            --dart-define=MEDIA_ORIGIN=http://10.0.2.2:8000
```

---

## 6. Запуск на iOS Simulator

Отдельного `.env.ios.json` тоже нет. iOS Simulator (в отличие от Android-эмулятора) делит сеть с хостом, поэтому локальный бэкенд доступен напрямую через `localhost`:

```bash
open -a Simulator

# Вариант А — против стейджа
flutter run --dart-define-from-file=.env.server.json

# Вариант Б — против локального docker-compose бэкенда (раздел 2)
flutter run --dart-define=BASE_URL=http://localhost:8000/api/v1 \
            --dart-define=MEDIA_ORIGIN=http://localhost:8000
```

---

## 6.5. Тестирование без реального Remarked

Единственный способ не трогать настоящую CRM зала — гонять «Вариант Б» (локальный `docker compose` бэкенд из раздела 2), а не `.env.server.json`. Почему это работает:

- `REMARKED_API_TOKEN`/`REMARKED_POINT_ID` в `.env` реальные (пришли из `.env.example`), но Remarked принимает запросы на создание/чтение брони только с whitelisted IP стейджа (`REMARKED_RESERVES_REFERER=185.98.7.12`). С твоей локальной машины/докера этот IP другой — Remarked такие запросы просто отклонит.
- Создание брони (`POST /bookings/`) не ждёт ответа от Remarked: запись сразу пишется в локальную Postgres, а синк в Remarked (`create_reserve_in_remarked`) уходит отдельной фоновой Celery-задачей. Если она упадёт (или Celery вообще не поднят) — сама бронь в твоей локальной базе всё равно создана, гость (приложение) ничего не заметит.
- Из-за этого статус брони никогда не подтянется из Remarked автоматически (синк идёт только на стейдже). Чтобы протестировать push «Ваша бронь подтверждена» — смени статус вручную в Django Admin (`http://localhost:8000/admin/`) своей локальной брони на `confirmed`. Push уйдёт по-настоящему (Firebase не зависит от Remarked), но CRM зала это не увидит вообще.

Что при этом не потестируешь локально (нужны реальные данные Remarked):
- Выбор зала/стола в форме бронирования — `GET /bookings/zones/` и `/bookings/tables/` при недоступном Remarked просто вернут ошибку, и Flutter-форма молча скроет выбор зала (см. `BookingProvider.loadZones()`), бронь всё равно создастся без привязки к конкретному столу.
- Синхронизацию статусов из Remarked (подтверждение/отмена реальным менеджером) — это фича только стейджа/прода.

---

## 7. Что потестить (MVP чеклист)

### Авторизация
- [ ] Ввод номера телефона → отправка SMS OTP
- [ ] Ввод 4-значного кода → вход в аккаунт
- [ ] Профиль отображает имя/телефон после входа
- [ ] Кнопка «Выйти» на экране профиля работает

### Меню
- [ ] Список блюд загружается с бэкенда
- [ ] Видео-карточки воспроизводят видео (свайп вверх/вниз)
- [ ] Свайп вправо открывает детальный лист блюда
- [ ] Цена отображается с символом ₸ и разделителем тысяч (`2 500 ₸`)
- [ ] Фильтр по категориям работает

### Мероприятия
- [ ] Список мероприятий загружается
- [ ] Дата/время на казахском языке
- [ ] Цена в тенге (`от 2 500 ₸`)
- [ ] Карточка мероприятия открывается
- [ ] Кнопка «Записаться» → форма записи (требует авторизации)

### Бронирование стола
- [ ] Форма бронирования открывается
- [ ] Выбор зоны / даты / времени / кол-ва гостей
- [ ] Кнопка «Назад» работает
- [ ] Бронь отправляется на бэкенд

### Профиль
- [ ] Настройки уведомлений сохраняются
- [ ] Logout сбрасывает состояние авторизации

---

## 8. Логи и отладка

### Логи бэкенда

```bash
docker compose logs -f backend    # Django
docker compose logs -f worker     # Celery worker
docker compose logs -f beat       # Celery beat
```

### Flutter

```bash
flutter logs    # логи устройства в реальном времени
```

### Проверить API вручную

```bash
# Список блюд
curl http://localhost:8000/api/v1/menu/dishes/

# Мероприятия
curl http://localhost:8000/api/v1/events/

# Информация о ресторане
curl http://localhost:8000/api/v1/core/info/

# Запрос OTP (замени номер)
curl -X POST http://localhost:8000/api/v1/users/auth/request-sms/ \
  -H "Content-Type: application/json" \
  -d '{"phone": "+77001234567"}'
```

---

## 9. Частые проблемы

### `DisallowedHost` в Django
Добавь свой IP в `ALLOWED_HOSTS` в `backend/.env`, затем:
```bash
docker compose up -d --force-recreate backend
```
> `docker compose restart` не перечитывает `.env` — нужен `--force-recreate`

### Меню не загружается / пустой экран
1. Проверь что контейнеры запущены: `docker compose ps`
2. Проверь API: `curl http://localhost:8000/api/v1/menu/dishes/`
3. Проверь `adb reverse` если на физическом устройстве

### Видео не воспроизводится на устройстве
Убедись что в `AndroidManifest.xml` есть `android:usesCleartextTraffic="true"` (уже добавлено).
Переподключи `adb reverse` если переподключал кабель.

### Порт 8000 уже занят
```bash
lsof -i :8000
kill -9 <PID>
```

### Сбросить базу данных полностью
```bash
docker compose down -v   # удаляет volumes с данными
docker compose up --build
docker compose exec backend python manage.py migrate
```
