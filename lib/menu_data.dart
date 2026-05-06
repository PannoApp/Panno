// Блюда ресторана Piligrim — концепция Modern Nomad.

// Диетические теги (по аналогии с ТЗ: острое, веган, содержит алкоголь, аллергены)
enum DishTag {
  spicy,    // острое
  vegan,    // веганское
  alcohol,  // содержит алкоголь
  gluten,   // содержит глютен
  nuts,     // содержит орехи
  dairy,    // содержит молочное
}

extension DishTagX on DishTag {
  String get label {
    switch (this) {
      case DishTag.spicy:   return 'Острое';
      case DishTag.vegan:   return 'Веган';
      case DishTag.alcohol: return 'Алкоголь';
      case DishTag.gluten:  return 'Глютен';
      case DishTag.nuts:    return 'Орехи';
      case DishTag.dairy:   return 'Молочное';
    }
  }
  bool get isAllergen => this == DishTag.gluten || this == DishTag.nuts || this == DishTag.dairy;
}

class MockMenuDish {
  const MockMenuDish({
    required this.id,
    required this.name,
    required this.category,
    required this.priceTenge,
    required this.description,
    required this.ingredients,
    required this.weight,
    this.story,
    this.tags = const [],
  });

  final int id;
  final String name;
  final String category;
  final int priceTenge;
  final String description;
  final String ingredients;
  final String weight;
  final String? story;
  final List<DishTag> tags;

  String get priceLabel => formatTenge(priceTenge);
}

String formatTenge(int value) {
  final s = value.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('\u202F');
    b.write(s[i]);
  }
  return '${b.toString()} ₸';
}

const List<MockMenuDish> kMockMenuDishes = [
  // ── Супы ──────────────────────────────────────────────────────────────────
  MockMenuDish(
    id: 1,
    name: 'Шорпа от шефа',
    category: 'Супы',
    priceTenge: 4800,
    description:
        'Насыщенный бульон из ягнёнка с черимшой, диким луком и яйцом. '
        'Рецепт передан через три поколения.',
    ingredients: 'Ягнёнок, черимша, дикий лук, куриное яйцо, морковь, специи',
    weight: '380 мл',
    story: 'Шорпа — сердце кочевого стола. Этот рецепт шеф привёз из Южного Казахстана, где его передавали от матери к дочери поколениями.',
    tags: [DishTag.gluten],
  ),
  MockMenuDish(
    id: 2,
    name: 'Крем-суп из степных грибов',
    category: 'Супы',
    priceTenge: 5200,
    description:
        'Дикие грибы, копчёное масло, семена джусая. '
        'Земля и дым в каждой ложке.',
    ingredients: 'Лесные грибы, сливки, копчёное масло, семена джусая, тимьян',
    weight: '320 мл',
    tags: [DishTag.vegan, DishTag.gluten],
  ),
  // ── Холодное ─────────────────────────────────────────────────────────────
  MockMenuDish(
    id: 3,
    name: 'Тар-тар из конины',
    category: 'Холодное',
    priceTenge: 6400,
    description:
        'Рубленая конина, трюфельный айоли, хрустящие гречишные чипсы. '
        'Номадская классика в новом прочтении.',
    ingredients: 'Конина (вырезка), трюфельное масло, яичный желток, каперсы, гречишные чипсы, микрозелень',
    weight: '180 г',
    story: 'Конина — главное мясо кочевника. Здесь она сырая, как в древности, но обрамлена в современный контекст трюфеля и гречки.',
    tags: [DishTag.gluten],
  ),
  MockMenuDish(
    id: 4,
    name: 'Карпаччо из верблюжатины',
    category: 'Холодное',
    priceTenge: 6800,
    description:
        'Тонкие ломтики верблюжатины, рукола, вяленые томаты, выдержанный сыр.',
    ingredients: 'Верблюжатина (вырезка), рукола, вяленые томаты, выдержанный сыр, оливковое масло, лимон',
    weight: '160 г',
    tags: [DishTag.dairy],
  ),
  // ── Горячее ──────────────────────────────────────────────────────────────
  MockMenuDish(
    id: 5,
    name: 'Бешбармак от шефа',
    category: 'Горячее',
    priceTenge: 8400,
    description:
        'Ягнёнок томлённый 12 часов, листы теста собственного производства, '
        'бульон с зеленью.',
    ingredients: 'Ягнёнок (лопатка), тесто на яйцах, лук, петрушка, укроп, чёрный перец',
    weight: '450 г',
    story: 'Бешбармак переводится как "пять пальцев" — так его ели предки, руками, объединяясь за общим дастарханом. Шеф томит мясо 12 часов, сохраняя этот дух.',
    tags: [DishTag.gluten],
  ),
  MockMenuDish(
    id: 6,
    name: 'Казы фламбе',
    category: 'Горячее',
    priceTenge: 7200,
    description:
        'Традиционная казы на гриле, фламбированная коньяком. '
        'Смородиновый соус, жжёный лук.',
    ingredients: 'Конская казы, коньяк, чёрная смородина, лук, тимьян, сливочное масло',
    weight: '220 г',
    story: 'Огонь — ключевой образ Piligrim. Фламбирование казы — не шоу, а обряд: огонь раскрывает вкус, как предки раскрывали смысл жизни через костёр.',
    tags: [DishTag.alcohol],
  ),
  MockMenuDish(
    id: 7,
    name: 'Каурдак в медном котле',
    category: 'Горячее',
    priceTenge: 9200,
    description:
        'Субпродукты ягнёнка с репчатым луком и острым перцем. '
        'Подача в традиционном медном котле.',
    ingredients: 'Субпродукты ягнёнка (лёгкое, печень, сердце), лук, острый перец, картофель, зира',
    weight: '380 г',
    tags: [DishTag.spicy],
  ),
  MockMenuDish(
    id: 8,
    name: 'Стейк Wagyu A4',
    category: 'Горячее',
    priceTenge: 14800,
    description:
        'Японская мраморная говядина, соус дэми-гляс, '
        'печёный лук, пепел от саксаула.',
    ingredients: 'Wagyu A4 (рибай), соус дэми-гляс, лук-шалот, пепел саксаула, морская соль флёр де сель',
    weight: '280 г',
    story: 'Саксаул — дерево пустыни, свидетель тысяч кочевий. Его пепел придаёт стейку дымный привкус степного ветра. Восток встречает Запад на одной тарелке.',
    tags: [],
  ),
  MockMenuDish(
    id: 9,
    name: 'Манты с тыквой',
    category: 'Горячее',
    priceTenge: 5600,
    description:
        'Паровые манты с ягнёнком и тыквой, кумысная сметана, '
        'зелёное травяное масло.',
    ingredients: 'Ягнёнок, тыква, лук, тесто на яйцах, кумысная сметана, укроп, мята',
    weight: '340 г',
    tags: [DishTag.gluten, DishTag.dairy],
  ),
  // ── Десерты ──────────────────────────────────────────────────────────────
  MockMenuDish(
    id: 10,
    name: 'Баурсаки с варёной сгущёнкой',
    category: 'Десерты',
    priceTenge: 3800,
    description:
        'Воздушные баурсаки, крем из домашней варёной сгущёнки, '
        'кедровые орехи.',
    ingredients: 'Мука, яйца, молоко, сухие дрожжи, варёная сгущёнка, кедровые орехи, масло для жарки',
    weight: '200 г',
    tags: [DishTag.gluten, DishTag.dairy, DishTag.nuts],
  ),
  MockMenuDish(
    id: 11,
    name: 'Чак-чак с шафраном',
    category: 'Десерты',
    priceTenge: 3400,
    description:
        'Хрустящее тесто, мёд с шафраном и кардамоном, '
        'свежие лесные ягоды.',
    ingredients: 'Мука, яйца, мёд, шафран, кардамон, лесные ягоды',
    weight: '180 г',
    tags: [DishTag.gluten],
  ),
  // ── Напитки ──────────────────────────────────────────────────────────────
  MockMenuDish(
    id: 12,
    name: 'Кумыс игристый',
    category: 'Напитки',
    priceTenge: 2800,
    description:
        'Натуральный кумыс, слабогазированный. '
        'Живой, свежий, без добавок.',
    ingredients: 'Кобылье молоко, натуральные молочнокислые бактерии',
    weight: '250 мл',
    story: 'Кумыс — живой напиток кочевников, источник силы и здоровья. Наш кумыс готовят каждое утро по традиционному рецепту.',
    tags: [DishTag.dairy],
  ),
  MockMenuDish(
    id: 13,
    name: 'Чай из степных трав',
    category: 'Напитки',
    priceTenge: 1800,
    description:
        'Тимьян, чабрец и мята — ручной сбор из предгорий. '
        'Рецепт шефа.',
    ingredients: 'Тимьян, чабрец, мята, чёрная смородина (листья), мёд',
    weight: '400 мл',
    tags: [DishTag.vegan],
  ),
  // ── Вино ─────────────────────────────────────────────────────────────────
  MockMenuDish(
    id: 14,
    name: 'Château de la Steppe',
    category: 'Вино',
    priceTenge: 9200,
    description:
        'Казахстанское каберне-совиньон, 18 месяцев в дубе. '
        'Алматинская область, 2021.',
    ingredients: 'Каберне-совиньон (100%), Алматинская область',
    weight: '150 мл',
    story: 'Первое казахстанское вино международного класса. Виноград выращен у подножия Тянь-Шаня, где горный воздух и резкий климат дают ягоде особую силу.',
    tags: [DishTag.alcohol],
  ),
];

List<MockMenuDish> seasonalPicksFromMock() {
  const ids = <int>[1, 3, 6, 10];
  final byId = {for (final d in kMockMenuDishes) d.id: d};
  return ids.map((id) => byId[id]!).toList(growable: false);
}
