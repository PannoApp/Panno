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
