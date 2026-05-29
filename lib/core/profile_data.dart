// Данные экрана Профиль / Контакты — отделены от UI
// Согласно ТЗ раздел 4.5 и brand concept «Герой»
import 'package:flutter/material.dart';
import 'theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Герой приложения
// ─────────────────────────────────────────────────────────────────────────────
class HeroUser {
  const HeroUser({
    required this.name,
    required this.phone,
    this.journeyStartLabel,
    this.bookingsCount = 0,
    this.eventsCount = 0,
  });

  final String name;
  final String phone;
  final String? journeyStartLabel;
  final int bookingsCount;
  final int eventsCount;

  bool get isAuthorized => name.isNotEmpty;
}

// Анонимный герой — путь ещё не начат
const kAnonymousHero = HeroUser(name: '', phone: '');

// UI-заглушка для демонстрации экрана (до интеграции авторизации)
const kDemoUser = HeroUser(
  name: 'Герой без имени',
  phone: '+7 ··· ··· ·· ··',
  journeyStartLabel: '2 года',
  bookingsCount: 0,
  eventsCount: 0,
);

// ─────────────────────────────────────────────────────────────────────────────
// Контакты ресторана
// ─────────────────────────────────────────────────────────────────────────────
class MapTarget {
  const MapTarget({
    required this.label,
    required this.url,
    required this.totemAsset,
  });
  final String label;
  final String url;
  final String totemAsset;
}

const kRestaurantAddress = 'Астана, ул. Туран 24, НП «Шала»';
const kRestaurantPhone = '+7 (700) 000-00-00';
const kRestaurantVersion = '1.0.0 (build 1)';

class Messenger {
  const Messenger({
    required this.label,
    required this.url,
    required this.color,
    required this.iconAsset,
  });
  final String label;
  final String url;
  final Color color;
  final String iconAsset;
}

const kMessengers = [
  Messenger(
    label: 'WhatsApp',
    url: 'https://wa.me/77000000000',
    color: PiligrimColors.steppe,
    iconAsset: 'assets/images/whatsappsvg.svg',
  ),
  Messenger(
    label: 'Telegram',
    url: 'https://t.me/piligrim_astana',
    color: PiligrimColors.steppe,
    iconAsset: 'assets/images/telegramsvg.svg',
  ),
  Messenger(
    label: 'Instagram',
    url: 'https://instagram.com/piligrim.astana',
    color: PiligrimColors.steppe,
    iconAsset: 'assets/images/instagramsvg.svg',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Правила посещения
// ─────────────────────────────────────────────────────────────────────────────
class VisitRule {
  const VisitRule({
    required this.title,
    required this.body,
    required this.iconAsset,
  });
  final String title;
  final String body;
  final String iconAsset;
}

const kVisitRules = [
  VisitRule(
    title: 'Дресс-код',
    body:
        'Деловой casual. Ресторан выдержан в духе «Modern Nomad» — уважайте пространство. '
        'Спортивная одежда и шорты не рекомендованы в вечернее время.',
    iconAsset: 'assets/images/shaman.svg',
  ),
  VisitRule(
    title: 'Дети',
    body:
        'Дети приветствуются до 21:00. После 21:00 просьба согласовать визит с хостес.',
    iconAsset: 'assets/images/sun.svg',
  ),
  VisitRule(
    title: 'Питомцы',
    body: 'Питомцы допускаются на летней террасе при наличии поводка.',
    iconAsset: 'assets/images/bird_totem (1).svg',
  ),
  VisitRule(
    title: 'Фотосъёмка',
    body:
        'Съёмка блюд и атмосферы приветствуется. Профессиональная фото/видеосъёмка — '
        'по согласованию с менеджером.',
    iconAsset: 'assets/images/spiral.svg',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Push-уведомления — категории
// ─────────────────────────────────────────────────────────────────────────────
class NotifCategory {
  const NotifCategory({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.iconAsset,
  });
  final String id;
  final String label;
  final String subtitle;
  final String iconAsset;
}

const kNotifCategories = [
  NotifCategory(
    id: 'events',
    label: 'Мероприятия',
    subtitle: 'Анонсы вечеров и концертов',
    iconAsset: 'assets/images/tree_totem (1).svg',
  ),
  NotifCategory(
    id: 'promo',
    label: 'Акции',
    subtitle: 'Спецпредложения и скидки',
    iconAsset: 'assets/images/star_totem (1).svg',
  ),
  NotifCategory(
    id: 'private',
    label: 'Закрытые события',
    subtitle: 'Только для Героев',
    iconAsset: 'assets/images/moon_totem (1).svg',
  ),
];
