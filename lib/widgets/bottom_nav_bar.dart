// PILIGRIM — встроенный нижний футер (не плавающий док). На всю ширину, у края safe area.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import 'piligrim_tap.dart';

const Color _kNavActive   = PiligrimColors.water;
const Color _kNavInactive = PiligrimColors.navInactive;
const Color _kNavRimTop   = PiligrimColors.navBarRim;

const Duration _kDur   = Duration(milliseconds: 350);
const Curve    _kCurve = Curves.easeInOutCubic;

class PiligrimNavBar extends StatelessWidget {
  const PiligrimNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(label: 'Главная',  asset: 'assets/images/star_totem (1).svg'),
    _NavItem(label: 'Меню',     asset: 'assets/images/bird_totem (1).svg'),
    _NavItem(label: 'Интерьер', asset: 'assets/images/wheel_totem (1).svg'),
    _NavItem(label: 'Афиша',    asset: 'assets/images/tree_totem (1).svg'),
    _NavItem(label: 'Профиль',  asset: 'assets/images/shaman.svg'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PiligrimColors.navBarBase,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PiligrimColors.navBarTop,
              PiligrimColors.navBarBase,
              PiligrimColors.earthDeep,
            ],
            stops: [0.0, 0.35, 1.0],
          ),
          border: Border(
            top: BorderSide(color: _kNavRimTop, width: 0.5),
          ),
          boxShadow: PiligrimShadows.nav,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_items.length, (i) {
                final item = _items[i];
                final active = i == currentIndex;
                return Expanded(
                  child: PiligrimTap(
                    onTap: () => onTap(i),
                    child: _NavTabCell(item: item, active: active),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavTabCell extends StatelessWidget {
  const _NavTabCell({required this.item, required this.active});

  final _NavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NavTotemIcon(asset: item.asset, active: active),
        const SizedBox(height: 4),
        // Индикатор активного таба — тонкая линия с glow
        AnimatedContainer(
          duration: _kDur,
          curve: _kCurve,
          height: 1.5,
          width: active ? 20.0 : 0.0,
          decoration: BoxDecoration(
            color: active
                ? _kNavActive.withValues(alpha: 0.65)
                : PiligrimColors.clear,
            borderRadius: BorderRadius.circular(1),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _kNavActive.withValues(alpha: 0.30),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 4),
        // Подпись — плавный переход цвета и letter-spacing
        AnimatedDefaultTextStyle(
          duration: _kDur,
          curve: _kCurve,
          style: PiligrimTextStyles.caption.copyWith(
            fontSize: 10,
            height: 1.05,
            color: active ? _kNavActive : _kNavInactive,
            letterSpacing: active ? 0.6 : 0.9,
          ),
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavTotemIcon extends StatelessWidget {
  const _NavTotemIcon({required this.asset, required this.active});

  final String asset;
  final bool active;

  static const double _sizeActive   = 24.0;
  static const double _sizeInactive = 20.0;
  // Масштаб иконки в неактивном состоянии (относительно активного)
  static const double _inactiveScale = _sizeInactive / _sizeActive;

  @override
  Widget build(BuildContext context) {
    final isHeavyGlyph = asset.contains('moon') || asset.contains('shaman');
    final renderSize = _sizeActive * (isHeavyGlyph ? 0.88 : 1.0);

    return SizedBox(
      width: 40,
      height: _sizeActive,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Glow — видим только на активном табе
          if (active)
            IgnorePointer(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PiligrimColors.water.withValues(alpha: 0.22),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          // Иконка — плавное масштабирование через AnimatedScale
          AnimatedScale(
            scale: active ? 1.0 : _inactiveScale,
            duration: _kDur,
            curve: _kCurve,
            child: SvgPicture.asset(
              asset,
              width: renderSize,
              height: renderSize,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(
                active ? _kNavActive : _kNavInactive,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({required this.label, required this.asset});
  final String label;
  final String asset;
}
