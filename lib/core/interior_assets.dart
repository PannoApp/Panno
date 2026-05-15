// Растровые интерьеры PILIGRIM — единая карта ассетов (HQ PNG в assets/images).
import 'package:flutter/widgets.dart';

abstract final class PiligrimInteriorAssets {
  static const List<String> triptychInteriorAmbient = [
    'assets/images/interior_hero_21.png',
    'assets/images/interior_hero_12.png',
    'assets/images/interior_hero_13.png',
  ];

  /// Главный hero — те же кадры, что и глобальный триптих (визуальная непрерывность).
  static const List<String> homeHeroCycle = triptychInteriorAmbient;

  /// Ограничение декодирования полноширинных интерьеров (GPU / память).
  /// Для `assets/images/interior_hero_*` или будущей папки `assets/interior2/`
  /// передавайте результат в `Image.asset(cacheWidth: …)`.
  static int decodeCacheWidth(BuildContext context, {double widthFactor = 1.12}) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width * widthFactor * mq.devicePixelRatio;
    return w.round().clamp(768, 1680);
  }

  static int decodeCacheHeight(BuildContext context, double logicalHeight,
      {double heightFactor = 1.18}) {
    final mq = MediaQuery.of(context);
    final h = logicalHeight * heightFactor * mq.devicePixelRatio;
    return h.round().clamp(900, 2200);
  }

  /// Все интерьерные PNG (`interior_hero_1` … `interior_hero_21`) — афиша, бронь, обложки.
  static final List<String> allInteriorPngs = List<String>.unmodifiable(
    List.generate(
      21,
      (i) => 'assets/images/interior_hero_${i + 1}.png',
    ),
  );

  /// Два кадра для превью в «Фотоотчёте», отличных от обложки события.
  static List<String> galleryExtrasExcluding(String coverAssetPath) {
    final all = allInteriorPngs;
    var idx = all.indexOf(coverAssetPath);
    if (idx < 0) idx = 0;
    String pick(int offset) {
      var j = (idx + offset) % all.length;
      var path = all[j];
      var guard = 0;
      while (path == coverAssetPath && guard < all.length) {
        j = (j + 1) % all.length;
        path = all[j];
        guard++;
      }
      return path;
    }

    final a = pick(7);
    var b = pick(14);
    var tries = 0;
    while (b == a && tries < all.length) {
      b = pick(14 + tries + 1);
      tries++;
    }
    return [a, b];
  }
}
