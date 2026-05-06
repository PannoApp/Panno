// Модель блюда с атмосферными фото-градиентами (палитра Piligrim).
import 'package:flutter/material.dart';

import 'menu_data.dart';

class DishPhoto {
  final Color top;
  final Color mid;
  final Color bot;
  final Color glow;
  final Alignment glowCenter;

  const DishPhoto({
    required this.top,
    required this.mid,
    required this.bot,
    required this.glow,
    this.glowCenter = Alignment.center,
  });
}

class DishItem {
  final MockMenuDish data;
  final List<DishPhoto> photos;

  DishItem({required this.data, required this.photos});
}

// ── Атмосферные градиенты — палитра брендбука Piligrim ────────────────────────
// Тёмная земля (Қара жер) + акценты: вода (Мөлдір су) и степь (Сары дала)
const _catPhotos = <String, List<DishPhoto>>{
  'Супы': [
    DishPhoto(top: Color(0xFF1E1A14), mid: Color(0xFF2E2416), bot: Color(0xFF141008), glow: Color(0xFFC4956A), glowCenter: Alignment(0.2, -0.3)),
    DishPhoto(top: Color(0xFF261E14), mid: Color(0xFF382A18), bot: Color(0xFF1A140A), glow: Color(0xFFD4A878), glowCenter: Alignment(-0.3, 0.2)),
    DishPhoto(top: Color(0xFF181410), mid: Color(0xFF281E14), bot: Color(0xFF100C08), glow: Color(0xFFB88858), glowCenter: Alignment(0.4, 0.4)),
  ],
  'Холодное': [
    DishPhoto(top: Color(0xFF121820), mid: Color(0xFF1A2230), bot: Color(0xFF0C1018), glow: Color(0xFF7BA5B8), glowCenter: Alignment(0.0, -0.3)),
    DishPhoto(top: Color(0xFF141A24), mid: Color(0xFF1C2838), bot: Color(0xFF0E1220), glow: Color(0xFF90B8C8), glowCenter: Alignment(-0.3, 0.2)),
    DishPhoto(top: Color(0xFF0E1418), mid: Color(0xFF161C28), bot: Color(0xFF080C14), glow: Color(0xFF6898B0), glowCenter: Alignment(0.4, -0.2)),
  ],
  'Горячее': [
    DishPhoto(top: Color(0xFF201A14), mid: Color(0xFF2E2018), bot: Color(0xFF14100C), glow: Color(0xFFC4956A), glowCenter: Alignment(0.1, -0.2)),
    DishPhoto(top: Color(0xFF261E18), mid: Color(0xFF382818), bot: Color(0xFF181410), glow: Color(0xFFD4A878), glowCenter: Alignment(-0.2, 0.3)),
    DishPhoto(top: Color(0xFF181410), mid: Color(0xFF241A12), bot: Color(0xFF100C08), glow: Color(0xFFB88048), glowCenter: Alignment(0.4, -0.3)),
  ],
  'Десерты': [
    DishPhoto(top: Color(0xFF201C14), mid: Color(0xFF302618), bot: Color(0xFF14100A), glow: Color(0xFFD4B078), glowCenter: Alignment(0.0, -0.3)),
    DishPhoto(top: Color(0xFF241E16), mid: Color(0xFF342A1A), bot: Color(0xFF18120C), glow: Color(0xFFE0BE88), glowCenter: Alignment(-0.3, 0.2)),
    DishPhoto(top: Color(0xFF1C1810), mid: Color(0xFF2C2014), bot: Color(0xFF120E08), glow: Color(0xFFC8A860), glowCenter: Alignment(0.3, 0.4)),
  ],
  'Напитки': [
    DishPhoto(top: Color(0xFF101620), mid: Color(0xFF182030), bot: Color(0xFF0C1018), glow: Color(0xFF7BA5B8), glowCenter: Alignment(0.0, -0.4)),
    DishPhoto(top: Color(0xFF121820), mid: Color(0xFF1C2835), bot: Color(0xFF0E1220), glow: Color(0xFF8CB5C8), glowCenter: Alignment(-0.3, 0.1)),
    DishPhoto(top: Color(0xFF0C1018), mid: Color(0xFF141C28), bot: Color(0xFF080C12), glow: Color(0xFF6898B0), glowCenter: Alignment(0.4, -0.2)),
  ],
  'Вино': [
    DishPhoto(top: Color(0xFF1C1014), mid: Color(0xFF2C1820), bot: Color(0xFF120A10), glow: Color(0xFF8B3A4A), glowCenter: Alignment(0.0, -0.3)),
    DishPhoto(top: Color(0xFF201014), mid: Color(0xFF341C26), bot: Color(0xFF180A10), glow: Color(0xFF9A4458), glowCenter: Alignment(-0.2, 0.3)),
    DishPhoto(top: Color(0xFF180C10), mid: Color(0xFF241418), bot: Color(0xFF100A0C), glow: Color(0xFF7A2E3E), glowCenter: Alignment(0.4, 0.1)),
  ],
};

List<DishItem> buildDishItems() => kMockMenuDishes
    .map((d) => DishItem(
          data: d,
          photos: _catPhotos[d.category] ?? _catPhotos['Горячее']!,
        ))
    .toList();
