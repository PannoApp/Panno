# Экран «Интерьер» — Flutter-документация

## Обзор

`InteriorScreen` — вкладка #2 в `RootShell` (IndexedStack). Показывает фотогалерею ресторана с возможностью:
- просмотра по зонам (Главный зал, Терраса, Бар, …)
- fullscreen просмотра с pinch-to-zoom и листанием
- открытия 3D-тура в браузере (если настроен в админке)
- воспроизведения атмосферного фонового аудио

## Файлы

| Файл | Роль |
|------|------|
| `lib/screens/interior_screen.dart` | Основной экран + `_TourButton`, `_InteriorSlideTile` |
| `lib/screens/interior_photo_viewer.dart` | Fullscreen просмотрщик с `InteractiveViewer` |
| `lib/widgets/interior_zone_filter.dart` | Горизонтальный фильтр по зонам |
| `lib/widgets/interior_audio_button.dart` | Кнопка mute/unmute атмосферного аудио |

## Источники данных

| Данные | Откуда |
|--------|--------|
| `interiorSlides` | `CoreInfoProvider.interiorSlides` (из `GET /api/v1/core/interior/`) |
| `tourLink` | `CoreInfoProvider.coreInfo?.tourLink` (из `GET /api/v1/core/info/`) |

Оба запроса выполняются параллельно в `CoreInfoProvider.load()` при старте приложения.

## Фильтрация по зонам

В `build()` из списка `slides` вычисляются уникальные зоны:

```dart
final zones = slides
    .map((s) => (zone: s.zone, label: s.zoneDisplay))
    .toSet()
    .toList();
```

Состояние фильтра — `String? _selectedZone` в `_InteriorScreenState`.  
`null` — показывать все фото; непустая строка — только фото выбранной зоны.

Фильтр по зонам (`InteriorZoneFilter`) отображается только если `zones.length > 1`.

## Fullscreen просмотр (`InteriorPhotoViewer`)

Открывается через `PageRouteBuilder` с `FadeTransition + ScaleTransition(begin: 0.93)`:

```dart
Navigator.of(context).push(
  PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black87,
    pageBuilder: (_, __, ___) => InteriorPhotoViewer(
      slides: filtered,   // отфильтрованные фото текущей зоны
      initialIndex: i,
    ),
    ...
  ),
);
```

### Жесты в просмотрщике

| Жест | Действие |
|------|----------|
| Pinch / double-tap | Zoom (1.0–4.0) через `InteractiveViewer` |
| Горизонтальный свайп | Листание между фото (`PageView`) |
| Быстрый свайп вниз (velocity > 400) | Закрытие |
| Медленный drag вниз (> 100px) | Закрытие |
| Медленный drag, отпустить раньше | Пружина обратно |
| Кнопка X (верхний правый) | Закрытие |

В просмотрщике снизу отображается:
- `slide.zoneDisplay` — название зоны (заглавными, цвет `steppe`)
- `slide.caption` — подпись (если непустая)

## Атмосферное аудио

### Файл

`assets/audio/interior_ambient.mp3` — зацикленный эмбиент (рекомендуемые параметры: 30–60 сек, mono, 128 kbps, ≤ 500 KB). Файл воспроизводится через `audioplayers: ^6.1.0`.

### Lifecycle

Аудио управляется в `_InteriorScreenState`, который живёт постоянно (вкладка в `IndexedStack` + `wantKeepAlive = true`).

| Событие | Действие |
|---------|----------|
| `initState()` | `AudioPlayer` создаётся, запускается `_startAmbientAudio()` |
| `_startAmbientAudio()` успех | `_audioInitialized = true` → кнопка появляется |
| `_startAmbientAudio()` ошибка | `_audioInitialized` остаётся `false` → кнопка скрыта |
| `didUpdateWidget`: `isTabActive` false → true | `_audioPlayer.resume()` (если не замьючено) |
| `didUpdateWidget`: `isTabActive` true → false | `_audioPlayer.pause()` |
| `didChangeAppLifecycleState`: paused | `_audioPlayer.pause()` |
| `didChangeAppLifecycleState`: resumed | `_audioPlayer.resume()` (если не замьючено) |
| `dispose()` | `_audioPlayer.stop()` + `_audioPlayer.dispose()` |

`WidgetsBindingObserver` добавляется в `initState()` и удаляется в `dispose()`.

### Параметр `isTabActive`

```dart
class InteriorScreen extends StatefulWidget {
  const InteriorScreen({super.key, this.isTabActive = true});
  final bool isTabActive;
}
```

Передаётся из `RootShell` (`lib/main.dart`):
```dart
InteriorScreen(isTabActive: _currentIndex == 2),
```

Паттерн аналогичен `MenuScreen(isTabActive: _currentIndex == 1)`.

## 3D-тур

Кнопка «Виртуальный 3D-тур» отображается только при непустом `tourLink`:

```dart
if (tourLink != null && tourLink.isNotEmpty)
  SliverToBoxAdapter(child: _TourButton(onTap: () => _openTour(tourLink)));
```

Нажатие вызывает `url_launcher`:
```dart
launchUrl(uri, mode: LaunchMode.externalApplication)
```

Открывается в системном браузере (WebView не требуется). При ошибке — `SnackBar`.

## Чек-лист ручного тестирования

**3D-тур:**
- [ ] Кнопка отображается только при `tourLink != null` (задать в Django Admin → RestaurantInfo)
- [ ] Нажатие открывает системный браузер
- [ ] При отсутствии `tourLink` — кнопка полностью скрыта

**Фильтр зон:**
- [ ] Фильтр скрыт, если все фото в одной зоне (или фото нет)
- [ ] «Все» показывает полный список
- [ ] Выбор зоны мгновенно фильтрует сетку
- [ ] При смене зоны просмотрщик открывается в рамках отфильтрованных фото

**Fullscreen просмотр:**
- [ ] Тап открывает просмотрщик на правильном индексе
- [ ] Pinch-to-zoom работает (1.0–4.0)
- [ ] Горизонтальное листание PageView
- [ ] `caption` виден только если непустой
- [ ] Свайп вниз (быстрый) закрывает
- [ ] Кнопка X закрывает

**Аудио:**
- [ ] Аудио запускается при открытии вкладки «Интерьер»
- [ ] Переключение на другую вкладку — пауза
- [ ] Возврат — возобновление (если не замьючено вручную)
- [ ] Сворачивание приложения — пауза
- [ ] Кнопка переключает mute/unmute
- [ ] При отсутствии `interior_ambient.mp3` — кнопка скрыта, экран работает корректно
- [ ] Открытие просмотрщика не прерывает аудио
