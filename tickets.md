# ТЕХНИЧЕСКИЕ ЗАДАЧИ (ТИКЕТЫ) ДЛЯ РАЗРАБОТКИ · PILIGRIM APP

---

## 1. Сделать нормальный и красивый Toast с уведомлениями
**Статус**: Готов к реализации  
**Приоритет**: Высокий  

### Описание задачи
Текущий `PiligrimToast` отображается в самом верху по центру экрана, накладываясь на системный статус-бар и кнопки навигации в `AppBar`. Кроме того, при вызове нового уведомления старое резко исчезает, вызывая мерцание, и его нельзя смахнуть пальцем.

### Техническое решение
1. **Жесты и поведение**:
   * Обернуть виджет уведомления `_ToastWidget` в `Dismissible` (или использовать `GestureDetector` с отслеживанием свайпов), чтобы пользователь мог смахнуть уведомление влево/вправо или вверх.
2. **Премиальный UI-стиль ("Quiet Luxury")**:
   * Использовать `BackdropFilter` с `ImageFilter.blur(sigmaX: 12, sigmaY: 12)` для создания матового стекла (glassmorphism).
   * Цвет фона сделать полупрозрачным: `PiligrimColors.earthDeep.withValues(alpha: 0.72)`.
   * Слева добавить тонкую вертикальную полосу акцентного цвета (в зависимости от типа тоста: `water` для инфо, зеленый `success` для успешных операций, красный `fruit` для ошибок).
3. **Очередь уведомлений**:
   * Изменить логику в `PiligrimToast.show`. Вместо мгновенного удаления `_entry?.remove()` сделать плавную анимацию исчезновения, либо организовать простой стек уведомлений, чтобы сообщения не перекрывали друг друга резко.

### Файлы для изменения
* [lib/widgets/piligrim_toast.dart](file:///c:/Users/amanz/OneDrive/Desktop/Panno/lib/widgets/piligrim_toast.dart)

---

## 3. Стабильная работа приложения без интернета (Офлайн-режим)
**Статус**: Готов к реализации  
**Приоритет**: Высокий  

### Описание задачи
При отключении сети приложение должно плавно переходить в автономный режим: не падать, не показывать белые экраны и корректно информировать пользователя.

### Техническое решение
1. **Локальный кэш данных (Репозитории)**:
   * В репозиториях ([core_repository.dart](file:///c:/Users/amanz/OneDrive/Desktop/Panno/lib/data/repositories/core_repository.dart), `menu_repository.dart`, `events_repository.dart`) при успешном получении ответов от API сохранять JSON в `SharedPreferences`.
   * При перехвате `DioException` (ошибка сети/таймаут) считывать сохраненный кэш из `SharedPreferences` и возвращать его.
   * Передавать в провайдеры флаг `isOfflineMode = true`.
2. **Информирование**:
   * Если приложение работает на кэшированных данных, показывать вверху экрана аккуратный статус-бар: *"Офлайн-режим. Данные могут быть неактуальными"*.
3. **Заглушка для экрана «Интерьер»**:
   * В [interior_screen.dart](file:///c:/Users/amanz/OneDrive/Desktop/Panno/lib/screens/interior_screen.dart), если список слайдов пуст из-за сбоя сети, загружать локальные фотографии из [PiligrimInteriorAssets.allInteriorPngs](file:///c:/Users/amanz/OneDrive/Desktop/Panno/lib/core/interior_assets.dart#L31) в качестве элементов галереи, чтобы экран не оставался пустым.

### Файлы для изменения
* Репозитории в `lib/data/repositories/`
* Провайдеры in `lib/providers/` (`CoreInfoProvider`, `MenuProvider`, `EventsProvider`)
* [lib/screens/interior_screen.dart](file:///c:/Users/amanz/OneDrive/Desktop/Panno/lib/screens/interior_screen.dart)

---

## 4. Корректировка отображения и загрузки фотографий на главном экране
**Статус**: Готов к реализации  
**Приоритет**: Средний  

### Описание задачи
На главном экране картинки в блоке Hero имеют вертикальный формат. При загрузке горизонтальных фото (например, 16:9) они сильно обрезаются по бокам из-за фиксированного выравнивания `alignment: Alignment(0.0, 0.14)` и искусственного увеличения `1.26` под эффект параллакса гироскопа.

### Техническое решение
1. **Панель администратора (веб-интерфейс React/Django)**:
   * Настроить кроппер (кадрирование) или добавить валидацию при загрузке картинок для главного экрана, рекомендуя формат **9:16 (Portrait)**. Добавить подсказку: *"Загружайте вертикальные фото, важный контент по центру"*.
2. **Оптимизация во Flutter**:
   * В [home_hero_section.dart](file:///c:/Users/amanz/OneDrive/Desktop/Panno/lib/widgets/home_hero_section.dart) уменьшить масштаб изображения `_heroImageScale` с `1.26` до `1.12` - `1.15`. Это сохранит эффект параллакса, но значительно уменьшит обрезку боковых областей.
   * Изменить смещение `alignment` с `const Alignment(0.0, 0.14)` на центральное `Alignment.center`.

### Файлы для изменения
* [lib/widgets/home_hero_section.dart](file:///c:/Users/amanz/OneDrive/Desktop/Panno/lib/widgets/home_hero_section.dart)
* Код веб-панели управления (вне текущего репозитория Flutter)

---

## 7. Подготовка нативных конфигураций и разрешений для деплоя в App Store & Google Play
**Статус**: Готов к реализации  
**Приоритет**: Высокий  

### Описание задачи
Перед публикацией приложения в App Store и Google Play необходимо привести нативные конфигурационные файлы в полное соответствие с требованиями модераторов обеих платформ. Это включает настройку обязательных системных разрешений, политик приватности и видимости пакетов для корректной работы офлайн-режима, пуш-уведомлений и интеграции с внешними сервисами.

### Техническое решение
1. **Google Play (Android)**:
   * В [AndroidManifest.xml](file:///c:/Users/amanz/OneDrive/Desktop/Panno/android/app/src/main/AndroidManifest.xml) объявить разрешение на Интернет: `<uses-permission android:name="android.permission.INTERNET"/>` (для релизной сборки).
   * Добавить разрешение на отправку уведомлений (для Android 13+): `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`.
   * Добавить разрешение на отслеживание сети: `<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>`.
   * Дополнить блок `<queries>` схемами `tel`, `https`, `tg`, `dgis` для обеспечения Package Visibility на Android 11+.
   * Перевести `android:usesCleartextTraffic` в `false` после перехода API-сервера на HTTPS.
   * Настроить релизную подпись (Keystore) в [build.gradle.kts](file:///c:/Users/amanz/OneDrive/Desktop/Panno/android/app/build.gradle.kts).

2. **App Store (iOS)**:
   * В [Info.plist](file:///c:/Users/amanz/OneDrive/Desktop/Panno/ios/Runner/Info.plist) расширить описания разрешений (`NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryAddUsageDescription`), сделав их подробными и понятными для модераторов Apple.
   * Удалить временные HTTP-исключения `NSAppTransportSecurity` после перехода на HTTPS-домен.
   * Добавить скачанный из консоли Firebase файл `GoogleService-Info.plist` в Xcode-проект Runner.

3. **Модерация и доступ**:
   * Создать на бэкенде тестовый профиль с фиксированным номером телефона и статичным кодом подтверждения для прохождения проверки входа по SMS модераторами App Store и Google Play.
   * Проверить регулярное обновление номеров сборки (build numbers) в `pubspec.yaml` при отправке новых версий.

### Файлы для изменения
* [android/app/src/main/AndroidManifest.xml](file:///c:/Users/amanz/OneDrive/Desktop/Panno/android/app/src/main/AndroidManifest.xml)
* [android/app/build.gradle.kts](file:///c:/Users/amanz/OneDrive/Desktop/Panno/android/app/build.gradle.kts)
* [ios/Runner/Info.plist](file:///c:/Users/amanz/OneDrive/Desktop/Panno/ios/Runner/Info.plist)
* [pubspec.yaml](file:///c:/Users/amanz/OneDrive/Desktop/Panno/pubspec.yaml)
