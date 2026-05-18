// PILIGRIM — встроенный нижний футер (не плавающий док). На всю ширину, у края safe area.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import 'piligrim_tap.dart';

/// Тёплый коричнево-чёрный фон — почти непрозрачный, контент сзади не просвечивает.
const Color _kNavBase = Color(0xFF211D1A);
const Color _kNavTop = Color(0xFF2A2521);
const Color _kNavActive = Color(0xFF7BA5B8);
const Color _kNavInactive = Color(0x66F2EDE4);
const Color _kNavRimTop = Color(0x14F2EDE4);

class PiligrimNavBar extends StatelessWidget {
  const PiligrimNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(label: 'Главная', asset: 'assets/images/star_totem (1).svg'),
    _NavItem(label: 'Меню', asset: 'assets/images/bird_totem (1).svg'),
    _NavItem(label: 'Интерьер', asset: 'assets/images/wheel_totem (1).svg'),
    _NavItem(label: 'Афиша', asset: 'assets/images/tree_totem (1).svg'),
    _NavItem(label: 'Профиль', asset: 'assets/images/shaman.svg'),
  ];

  static const double _topRadius = 19;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kNavBase,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_topRadius),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _kNavTop,
              Color(0xF6211D1A),
              _kNavBase,
            ],
            stops: [0.0, 0.35, 1.0],
          ),
          border: Border(
            top: BorderSide(color: _kNavRimTop, width: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6,
              offset: Offset(0, -2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 5),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_items.length, (i) {
                final item = _items[i];
                final active = i == currentIndex;
                return Expanded(
                  child: PiligrimTap(
                    onTap: () => onTap(i),
                    child: _NavTabCell(
                      item: item,
                      active: active,
                    ),
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

class _NavTabCell extends StatelessWidget {
  const _NavTabCell({
    required this.item,
    required this.active,
  });

  final _NavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NavTotemIcon(asset: item.asset, active: active),
        const SizedBox(height: 2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          height: 2,
          width: active ? 14 : 0,
          decoration: BoxDecoration(
            color: active
                ? _kNavActive.withValues(alpha: 0.32)
                : _kNavRimTop,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: PiligrimTextStyles.caption.copyWith(
            fontSize: 8.25,
            height: 1.0,
            color: active ? _kNavActive : _kNavInactive,
            letterSpacing: 0.28,
          ),
        ),
      ],
    );
  }
}

class _NavTotemIcon extends StatelessWidget {
  const _NavTotemIcon({
    required this.asset,
    required this.active,
  });

  final String asset;
  final bool active;

  static const double _sizeInactive = 15;
  static const double _sizeActive = 19;

  @override
  Widget build(BuildContext context) {
    final isHeavyGlyph = asset.contains('moon') || asset.contains('shaman');
    final base = active ? _sizeActive : _sizeInactive;
    final iconSize = base * (isHeavyGlyph ? 0.84 : 1.0);

    return SizedBox(
      width: 40,
      height: _sizeActive,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.center,
        children: [
          if (active)
            IgnorePointer(
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A7BA5B8),
                      blurRadius: 5,
                      spreadRadius: -1,
                    ),
                  ],
                ),
              ),
            ),
          SvgPicture.asset(
            asset,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(
              active ? _kNavActive : _kNavInactive,
              BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.asset});
  final String label;
  final String asset;
}
