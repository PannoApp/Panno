// Данные экрана Меню — «Основной путь, каждое блюдо — приключение»
// Согласно ТЗ 4.2 и piligrim_design_spec.md (раздел 9)
import 'package:flutter/material.dart';
import 'theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ТЕГИ — иконки из набора тотемов
// ─────────────────────────────────────────────────────────────────────────────
enum DishTag {
  spicy,
  vegan,
  alcohol,
  glutenFree,
  signature,
  halal,
}

extension DishTagX on DishTag {
  String get label {
    switch (this) {
      case DishTag.spicy: return 'Острое';
      case DishTag.vegan: return 'Вегетарианское';
      case DishTag.alcohol: return 'Алкоголь';
      case DishTag.glutenFree: return 'Без глютена';
      case DishTag.signature: return 'Авторское';
      case DishTag.halal: return 'Халяль';
    }
  }

  String get iconAsset {
    switch (this) {
      case DishTag.spicy: return 'assets/images/luk.svg';
      case DishTag.vegan: return 'assets/images/zerno.svg';
      case DishTag.alcohol: return 'assets/images/cobyz.svg';
      case DishTag.glutenFree: return 'assets/images/stone.svg';
      case DishTag.signature: return 'assets/images/star_totem (1).svg';
      case DishTag.halal: return 'assets/images/moon_totem (1).svg';
    }
  }

  Color get color {
    switch (this) {
      case DishTag.spicy: return const Color(0xFFD4774A);     // ember-orange
      case DishTag.vegan: return const Color(0xFF7BAD7E);     // natural green
      case DishTag.alcohol: return const Color(0xFF8B6A9F);   // deep purple
      case DishTag.glutenFree: return PiligrimColors.water;
      case DishTag.signature: return PiligrimColors.steppe;
      case DishTag.halal: return const Color(0xFF7BA5A0);     // teal
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// КАТЕГОРИИ МЕНЮ
// ─────────────────────────────────────────────────────────────────────────────
class DishCategory {
  const DishCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.totemAsset,
    required this.accentColor,
  });

  final String id;
  final String title;
  final String subtitle;
  final String totemAsset;
  final Color accentColor;
}

const kDishCategories = [
  DishCategory(
    id: 'all',
    title: 'Весь путь',
    subtitle: '',
    totemAsset: 'assets/images/spiral.svg',
    accentColor: PiligrimColors.water,
  ),
  DishCategory(
    id: 'start',
    title: 'Начало пути',
    subtitle: 'Закуски',
    totemAsset: 'assets/images/bird_totem (1).svg',
    accentColor: PiligrimColors.water,
  ),
  DishCategory(
    id: 'main',
    title: 'Основной путь',
    subtitle: 'Горячее',
    totemAsset: 'assets/images/wheel_totem (1).svg',
    accentColor: PiligrimColors.steppe,
  ),
  DishCategory(
    id: 'steppe',
    title: 'Степная традиция',
    subtitle: 'Мясо и жаркое',
    totemAsset: 'assets/images/pegasus.svg',
    accentColor: Color(0xFFD4774A),
  ),
  DishCategory(
    id: 'earth',
    title: 'Земля',
    subtitle: 'Супы и каши',
    totemAsset: 'assets/images/stone.svg',
    accentColor: Color(0xFF9A7B5E),
  ),
  DishCategory(
    id: 'end',
    title: 'Завершение',
    subtitle: 'Десерты',
    totemAsset: 'assets/images/moon_totem (1).svg',
    accentColor: Color(0xFF8B6A9F),
  ),
  DishCategory(
    id: 'drinks',
    title: 'Напитки',
    subtitle: 'Тёплые и холодные',
    totemAsset: 'assets/images/spiral.svg',
    accentColor: PiligrimColors.water,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// БЛЮДО
// ─────────────────────────────────────────────────────────────────────────────
class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.nameSub,
    required this.description,
    required this.story,
    required this.price,
    required this.weight,
    required this.categoryId,
    required this.tags,
    required this.allergens,
    required this.gradientColors,
    required this.totemAsset,
  });

  final String id;
  final String name;
  final String nameSub;       // краткое на казахском / поэтичное
  final String description;   // 1–2 строки для видео-ленты
  final String story;         // История блюда для full-карточки
  final int price;            // тенге
  final String weight;        // вес / объём
  final String categoryId;
  final List<DishTag> tags;
  final List<String> allergens;
  final List<Color> gradientColors; // атмосферный градиент-заглушка вместо видео
  final String totemAsset;    // декоративный тотем на карточке
}

// ─────────────────────────────────────────────────────────────────────────────
// МОК-ДАННЫЕ (заменяются API)
// ─────────────────────────────────────────────────────────────────────────────
final kDishes = <Dish>[
  const Dish(
    id: 'd1',
    name: 'Самса с ягнёнком',
    nameSub: 'Қой етімен самса',
    description: 'Хрустящее тесто, сочная начинка из ягнёнка,\nтоплёное масло и зира.',
    story: 'Самса — это не просто закуска, это ворота к традиции. '
        'Наш пекарь выпекает её в тандыре каждое утро, '
        'сохраняя рецепт, который передавался через поколения кочевников.',
    price: 2400,
    weight: '220 г',
    categoryId: 'start',
    tags: [DishTag.signature, DishTag.halal],
    allergens: ['глютен', 'молоко'],
    gradientColors: [
      Color(0xFF4A2E1A),
      Color(0xFF2A1A0E),
      Color(0xFF3D2A18),
    ],
    totemAsset: 'assets/images/bird_totem (1).svg',
  ),
  const Dish(
    id: 'd2',
    name: 'Бешбармак реформа',
    nameSub: 'Жаңа бесбармақ',
    description: 'Авторская интерпретация главного казахского блюда.\nТонкое тесто, медленное мясо, жидкий лук.',
    story: 'Мы не переписываем традицию — мы её продолжаем. '
        'Бешбармак готовится 6 часов: баранина томится до мягкости, '
        'тесто раскатывается вручную, а лук карамелизируется на медленном огне.',
    price: 4800,
    weight: '400 г',
    categoryId: 'main',
    tags: [DishTag.signature, DishTag.halal],
    allergens: ['глютен'],
    gradientColors: [
      Color(0xFF3A2010),
      Color(0xFF5A3520),
      Color(0xFF2A1808),
    ],
    totemAsset: 'assets/images/wheel_totem (1).svg',
  ),
  const Dish(
    id: 'd3',
    name: 'Манты с тыквой и рикоттой',
    nameSub: 'Асқабақты манты',
    description: 'Нежное тесто, тыква с рикоттой и зеленью,\nподаётся с топлёным маслом и зирой.',
    story: 'Манты — это архитектура в миниатюре. '
        'Каждый складывается вручную нашими поварами в четыре '
        'аутентичных защипа, которые символизируют четыре стороны света.',
    price: 3200,
    weight: '300 г',
    categoryId: 'main',
    tags: [DishTag.vegan, DishTag.signature],
    allergens: ['глютен', 'молоко'],
    gradientColors: [
      Color(0xFF2A3A1A),
      Color(0xFF1A2A10),
      Color(0xFF3A4A28),
    ],
    totemAsset: 'assets/images/zerno.svg',
  ),
  const Dish(
    id: 'd4',
    name: 'Крем-суп из тыквы',
    nameSub: 'Асқабақ сорпасы',
    description: 'Бархатный суп из печёной тыквы,\nкокосового молока и имбиря.',
    story: 'Тыква — символ осени в степи. '
        'Мы запекаем её целиком с маслом и специями, '
        'затем перебиваем в бархатный крем с кокосовым молоком.',
    price: 1800,
    weight: '280 мл',
    categoryId: 'earth',
    tags: [DishTag.vegan, DishTag.glutenFree],
    allergens: [],
    gradientColors: [
      Color(0xFF4A3010),
      Color(0xFF6A4520),
      Color(0xFF3A2008),
    ],
    totemAsset: 'assets/images/stone.svg',
  ),
  const Dish(
    id: 'd5',
    name: 'Шашлык из ягнёнка',
    nameSub: 'Шашлық',
    description: 'Мариновка 24 часа, открытый огонь.\nПодаётся с лепёшкой и соусом из трав.',
    story: 'Огонь и мясо — древнейший дуэт степи. '
        'Маринад из лука, зиры и гранатового сока работает сутки, '
        'а угли от саксаула дают тот самый дым, который ни с чем не спутать.',
    price: 5600,
    weight: '350 г',
    categoryId: 'steppe',
    tags: [DishTag.spicy, DishTag.halal, DishTag.glutenFree],
    allergens: [],
    gradientColors: [
      Color(0xFF5A2010),
      Color(0xFF3A1408),
      Color(0xFF7A3520),
    ],
    totemAsset: 'assets/images/pegasus.svg',
  ),
  const Dish(
    id: 'd6',
    name: 'Чак-чак авторский',
    nameSub: 'Авторлық шақ-шақ',
    description: 'Хрустящее тесто, мёд с тимьяном,\nжареные орехи и сезонные ягоды.',
    story: 'Чак-чак — гимн сладкому завершению пути. '
        'Наш шеф добавляет тимьяновый мёд и немного морской соли, '
        'превращая традиционное лакомство в современный десерт.',
    price: 1600,
    weight: '160 г',
    categoryId: 'end',
    tags: [DishTag.signature],
    allergens: ['глютен', 'орехи', 'мёд'],
    gradientColors: [
      Color(0xFF3A2A08),
      Color(0xFF5A4018),
      Color(0xFF2A1E04),
    ],
    totemAsset: 'assets/images/moon_totem (1).svg',
  ),
  const Dish(
    id: 'd7',
    name: 'Кок-чай',
    nameSub: 'Көк шай',
    description: 'Зелёный чай с мятой и кардамоном,\nподаётся в традиционной пиале.',
    story: 'Чай в степи — не напиток, а ритуал. '
        'Каждая пиала несёт тепло встречи и покой осмысления пройденного пути.',
    price: 600,
    weight: '300 мл',
    categoryId: 'drinks',
    tags: [DishTag.vegan, DishTag.glutenFree],
    allergens: [],
    gradientColors: [
      Color(0xFF1A3A28),
      Color(0xFF0E2A1C),
      Color(0xFF2A4A38),
    ],
    totemAsset: 'assets/images/spiral.svg',
  ),
  const Dish(
    id: 'd8',
    name: 'Айран пенистый',
    nameSub: 'Айран',
    description: 'Домашний айран из ферментированного молока,\nс мятой и чёрным тмином.',
    story: 'Айран — спутник кочевника в долгом пути. '
        'Кислый и освежающий, он восстанавливает силы и напоминает: '
        'путь продолжается.',
    price: 900,
    weight: '250 мл',
    categoryId: 'drinks',
    tags: [DishTag.glutenFree],
    allergens: ['молоко'],
    gradientColors: [
      Color(0xFF2A2A3A),
      Color(0xFF1A1A2A),
      Color(0xFF3A3A4A),
    ],
    totemAsset: 'assets/images/cobyz.svg',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Хелперы
// ─────────────────────────────────────────────────────────────────────────────
List<Dish> dishesByCategory(String categoryId) {
  if (categoryId == 'all') return kDishes;
  return kDishes.where((d) => d.categoryId == categoryId).toList();
}

DishCategory categoryById(String id) {
  return kDishCategories.firstWhere(
    (c) => c.id == id,
    orElse: () => kDishCategories.first,
  );
}
