// Визуальный реестр тегов меню.
// Теги приходят с бека динамически (ApiTag); здесь только стили (иконка + цвет).
// Новый тег виден сразу после добавления в админке — без обновления приложения.
// Кастомный стиль добавляется разработчиком когда нужна иконка (не блокирует контент).
import 'package:flutter/material.dart';
import 'theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// СТИЛЬ ТЕГА
// ─────────────────────────────────────────────────────────────────────────────
class TagStyle {
  const TagStyle({required this.iconAsset, required this.color});
  final String iconAsset;
  final Color color;
}

// Дефолтный стиль для тегов, которых нет в реестре
const kDefaultTagStyle = TagStyle(
  iconAsset: 'assets/images/spiral.svg',
  color: PiligrimColors.water,
);

// Реестр стилей по отображаемому имени тега (без учёта регистра).
// Имена должны совпадать с тем, что задаёт администратор в бекенде.
const _kTagStyles = <String, TagStyle>{
  'острое':           TagStyle(iconAsset: 'assets/images/luk.svg',              color: PiligrimColors.water),
  'вегетарианское':   TagStyle(iconAsset: 'assets/images/zerno.svg',            color: PiligrimColors.tagVegetarian),
  'алкоголь':         TagStyle(iconAsset: 'assets/images/cobyz.svg',            color: PiligrimColors.tagAlcohol),
  'без глютена':      TagStyle(iconAsset: 'assets/images/stone.svg',            color: PiligrimColors.water),
  'авторское':        TagStyle(iconAsset: 'assets/images/star_totem (1).svg',   color: PiligrimColors.steppe),
  'халяль':           TagStyle(iconAsset: 'assets/images/moon_totem (1).svg',   color: PiligrimColors.tagHalal),
};

// Возвращает стиль по имени тега. Неизвестный тег → kDefaultTagStyle.
TagStyle tagStyleFor(String tagName) =>
    _kTagStyles[tagName.toLowerCase().trim()] ?? kDefaultTagStyle;
