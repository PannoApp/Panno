// Данные экрана Профиль / Контакты — отделены от UI
// Согласно ТЗ раздел 4.5 и brand concept «Герой»
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Герой приложения
// ─────────────────────────────────────────────────────────────────────────────
class HeroUser {
  const HeroUser({
    required this.name,
    required this.phone,
    this.journeyStartValue,
    this.journeyStartLabel,
    this.bookingsCount = 0,
    this.eventsCount = 0,
    this.cashback = 0,
    this.loyaltyPercent,
    this.loyaltyCardUrl,
  });

  final String name;
  final String phone;
  final String? journeyStartValue;
  final String? journeyStartLabel;
  final int bookingsCount;
  final int eventsCount;
  final double cashback;
  final String? loyaltyPercent;
  final String? loyaltyCardUrl;

  bool get isAuthorized => name.isNotEmpty;
}

// Анонимный герой — путь ещё не начат
const kAnonymousHero = HeroUser(name: '', phone: '');

// UI-заглушка для демонстрации экрана (до интеграции авторизации)
const kDemoUser = HeroUser(
  name: 'Герой без имени',
  phone: '+7 ··· ··· ·· ··',
  journeyStartValue: '2',
  journeyStartLabel: 'Года с нами',
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
const kRestaurantPhone = '+7 (775) 007-62-70';
const kRestaurantVersion = '1.0.0 (build 1)';

// Восстановление номера лояльности (ТЗ по входу, п.4) — фолбэк, пока
// RestaurantInfo.loyalty_recovery_whatsapp/_message не заполнены в админке.
const kLoyaltyRecoveryWhatsapp = '+77713333044';
const kLoyaltyRecoveryMessage =
    'Здравствуйте! Не могу найти номер участника лояльности в приложении Piligrim, помогите, пожалуйста.';

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

// WhatsApp/Telegram/Instagram убраны из контактов профиля — оставляем
// класс Messenger (используется в _ContactsCard как fallback-тип), но
// список пуст, пока бэкенд не отдаёт social_links.
const kMessengers = <Messenger>[];

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
