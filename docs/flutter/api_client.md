# API Client

Слой HTTP-клиента построен на [Dio](https://pub.dev/packages/dio) с JWT-интерцептором и автоматическим рефрешем токенов.

Исходники: `lib/data/services/api_client.dart`, `lib/data/services/token_storage.dart`

---

## DioClient

Синглтон, который держит настроенный экземпляр `Dio` и стрим событий разлогина.

```dart
// Получить экземпляр
final client = DioClient.instance;

// Сделать запрос
final response = await client.dio.get('/menu/categories/');

// Подписаться на принудительный выход (401 без возможности рефреша)
DioClient.instance.onUnauthenticated.stream.listen((_) {
  // перейти на экран логина
});
```

### Свойства

| Свойство | Тип | Описание |
|---|---|---|
| `dio` | `Dio` | Настроенный HTTP-клиент. Все запросы делать через него. |
| `onUnauthenticated` | `StreamController<void>` | Бродкаст-стрим. Срабатывает, когда refresh не удался и токены очищены. |

---

## baseUrl — конфигурация для dev и prod

`baseUrl` задаётся через `--dart-define-from-file` при сборке и не хардкодится в коде.

```dart
static const _baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://piligrim.kz/api/v1',
);
```

Создайте файлы с переменными окружения:

**`dart_defines/dev.json`**
```json
{
  "BASE_URL": "http://10.0.2.2:8000/api/v1"
}
```
> `10.0.2.2` — Android-эмулятор. Для iOS-симулятора используйте `http://localhost:8000/api/v1`.

**`dart_defines/prod.json`**
```json
{
  "BASE_URL": "https://piligrim.kz/api/v1"
}
```

Запуск с нужным окружением:
```bash
# dev (Android-эмулятор)
flutter run --dart-define-from-file=dart_defines/dev.json

# prod-сборка
flutter build apk --dart-define-from-file=dart_defines/prod.json
```

Если файл не передан — используется `defaultValue` (prod URL).

---

## TokenStorage

Обёртка над `flutter_secure_storage`. Хранит пару JWT-токенов в Keychain (iOS) / EncryptedSharedPreferences (Android).

```dart
final storage = TokenStorage.instance;

// Сохранить токены после успешного логина
await storage.saveTokens(access: '...', refresh: '...');

// Прочитать
final accessToken  = await storage.readAccess();   // String?
final refreshToken = await storage.readRefresh();  // String?

// Очистить при явном логауте
await storage.clearTokens();
```

### API

| Метод | Сигнатура | Описание |
|---|---|---|
| `saveTokens` | `Future<void> saveTokens({required String access, required String refresh})` | Сохраняет оба токена параллельно. |
| `readAccess` | `Future<String?> readAccess()` | Возвращает access-токен или `null`. |
| `readRefresh` | `Future<String?> readRefresh()` | Возвращает refresh-токен или `null`. |
| `clearTokens` | `Future<void> clearTokens()` | Удаляет оба токена параллельно. |

---

## JWT Flow

```
┌─────────────┐     запрос     ┌──────────────┐
│  AuthInter  │ ─────────────► │   Backend    │
│  ceptor     │                │              │
│  onRequest  │ ◄────────────  │  200 OK      │  ✓ Обычный успешный путь
└─────────────┘                └──────────────┘

┌─────────────┐     запрос     ┌──────────────┐
│  AuthInter  │ ─────────────► │   Backend    │
│  ceptor     │ ◄──────────── │  401         │  access истёк
│  onError    │                └──────────────┘
│             │  POST /users/auth/token/refresh/
│             │ ─────────────► ┌──────────────┐
│             │ ◄────────────  │  200 + новые │  токены сохранены
│             │                │  токены      │
│             │  повтор исходного запроса
│             │ ─────────────► ┌──────────────┐
│             │ ◄────────────  │  200 OK      │  ✓ Прозрачно для вызывающего
└─────────────┘                └──────────────┘

                  refresh тоже вернул 401
                  ─────────────────────────►  clearTokens() + onUnauthenticated
```

### Детали реализации

- `AuthInterceptor` расширяет `Interceptor` (не `QueuedInterceptor`) — это позволяет делать вложенные запросы из `onError` без дедлока.
- Запросы с `extra: {'_retry': true}` пропускаются в `onError` — защита от рекурсивного рефреша.
- Refresh-запрос и retry помечаются флагом `_retry: true`.

---

## Стандартные тексты ошибок

Все сетевые ошибки приводятся к читаемой русской строке через `dioErrorMessage()` из `lib/core/dio_errors.dart`. Функция вызывается в каждом провайдере в блоке `catch`.

| Причина | Условие | Текст |
|---|---|---|
| Таймаут соединения | `DioExceptionType.connectionTimeout` | `'Нет соединения'` |
| Таймаут получения данных | `DioExceptionType.receiveTimeout` | `'Нет соединения'` |
| Таймаут отправки | `DioExceptionType.sendTimeout` | `'Нет соединения'` |
| Нет сети | `DioExceptionType.connectionError` | `'Нет соединения'` |
| Ошибка сервера | `statusCode >= 500` | `'Сервер временно недоступен'` |
| Ошибка клиента с `message`/`detail`/`error` в теле | `statusCode >= 400`, поле в `data` | Строка из тела ответа |
| Прочие 4xx | `statusCode >= 400`, поле не найдено | `'Ошибка запроса'` |
| Всё остальное | — | `'Что-то пошло не так'` |

Использование:

```dart
} catch (e) {
  error = dioErrorMessage(e); // всегда возвращает непустую строку
}
```

---

## Паттерн retry() в новых экранах

Все экраны следуют одному соглашению: провайдер хранит `String? error`, экран отображает `ErrorView` при ненулевом значении и вызывает `provider.retry()` по нажатию кнопки.

**1. В провайдере** — добавьте метод `retry()`:

```dart
// Вызов load() сбрасывает error = null внутри loadXxx(refresh: true)
// и делает повторный запрос. Не нужно вручную обнулять error здесь.
Future<void> retry() => load();
```

**2. На экране** — покажите `ErrorView` когда данные не загружены:

```dart
// В build():
final provider = context.watch<MyProvider>();

if (provider.error != null && provider.items.isEmpty) {
  return ErrorView(
    message: provider.error!,
    onRetry: provider.retry,
  );
}
```

> Если данные уже загружены (stale), не заменяйте их ошибкой — показывайте SnackBar или inline-баннер. `ErrorView` только для пустого состояния.

**Sliver-вариант** (внутри `CustomScrollView`):

```dart
if (provider.error != null && provider.items.isEmpty)
  SliverErrorView(message: provider.error!, onRetry: provider.retry),
```

`SliverErrorView` — обёртка из `lib/widgets/error_view.dart`, оба виджета готовы к использованию.

---

## Проверка версии при старте

`SplashScreen` автоматически сверяет версию приложения с бэкендом и блокирует запуск, если версия ниже минимально допустимой.

### Где хранится текущая версия

```dart
// lib/core/theme.dart
const String kAppVersion = '1.0.0';
```

Обновляйте эту константу при каждом релизе синхронно с `version` в `pubspec.yaml`.

### Логика проверки

```
Запуск → 3200 мс анимации → GET /api/v1/core/app-version/?platform=ios|android
         ↓
current < minVersion  →  неотклоняемый AlertDialog + кнопка «Обновить» → магазин
         ↓
minVersion ≤ current < latestVersion  →  отклоняемый баннер поверх splash + кнопка «Обновить»
         ↓
current == latestVersion  →  переход на главный экран без уведомлений
```

Ошибка сети молча игнорируется — запуск не блокируется.

### Модель ответа бэкенда

```json
{
  "platform": "ios",
  "min_version": "1.0.0",
  "latest_version": "1.2.0",
  "store_url": "https://apps.apple.com/..."
}
```

Endpoint: `GET /api/v1/core/app-version/?platform=<ios|android>`

---

## Как добавить force-update при релизе

**Шаг 1.** Соберите и выложите новую версию в App Store / Google Play.

**Шаг 2.** Обновите `kAppVersion` в `lib/core/theme.dart` и `version` в `pubspec.yaml`:

```dart
// lib/core/theme.dart
const String kAppVersion = '1.2.0'; // новая версия
```

```yaml
# pubspec.yaml
version: 1.2.0+5
```

**Шаг 3.** В Django Admin или через API поднимите `min_version` для нужной платформы:

| Сценарий | `min_version` | `latest_version` | Результат |
|---|---|---|---|
| Обязательное обновление | `1.2.0` | `1.2.0` | Пользователи < 1.2.0 заблокированы |
| Рекомендуемое обновление | `1.0.0` | `1.2.0` | Баннер, но пускает в приложение |
| Нет требований | `1.0.0` | `1.0.0` | Без уведомлений |

> `min_version` — жёсткий порог. Поднимайте его только после того, как новая версия опубликована в магазине и прошла ревью, иначе пользователи будут заблокированы без возможности обновиться.

**Шаг 4.** Убедитесь, что `store_url` актуален для обеих платформ — он подставляется напрямую в кнопку «Обновить».

---

## Добавление нового endpoint

Создайте отдельный сервис в `lib/data/services/`. Используйте `DioClient.instance.dio` напрямую — интерцептор навесит токен автоматически.

```dart
// lib/data/services/menu_service.dart

import 'package:dio/dio.dart';
import 'api_client.dart';

class MenuService {
  MenuService._();
  static final MenuService instance = MenuService._();

  final Dio _dio = DioClient.instance.dio;

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _dio.get('/menu/categories/');
    return List<Map<String, dynamic>>.from(response.data['results']);
  }

  Future<Map<String, dynamic>> getDish(int id) async {
    final response = await _dio.get('/menu/dishes/$id/');
    return response.data as Map<String, dynamic>;
  }
}
```

### Чеклист при добавлении endpoint

- [ ] Сервис создаётся как синглтон (`._()` + `instance`)
- [ ] Использует `DioClient.instance.dio`, а не создаёт новый `Dio`
- [ ] Не занимается токенами вручную — это делает `AuthInterceptor`
- [ ] Для публичных endpoint'ов (не требующих авторизации) используйте тот же `dio` — отсутствие токена обрабатывается корректно
- [ ] Полный список endpoint'ов и форматы ответов — в `backend/API_FOR_FLUTTER.md`
