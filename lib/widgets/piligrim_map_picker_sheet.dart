import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme.dart';
import 'piligrim_tap.dart';

/// Один вариант карты в шторке выбора.
class MapOption {
  const MapOption({required this.label, required this.url});
  final String label;
  final String url;
}

/// Строит варианты карт из адреса ресторана (Google/Яндекс/Apple — поиск по
/// адресу, универсальные ссылки работают без API-ключей) и точной ссылки
/// 2ГИС из админки (RestaurantInfo.twogis_link), если она задана.
/// Раньше кнопка «карты» жёстко открывала только 2ГИС — теперь гость сам
/// выбирает, каким приложением пользоваться.
List<MapOption> buildMapOptions({
  required String address,
  String? twogisLink,
}) {
  final query = Uri.encodeComponent(address);
  final options = <MapOption>[
    if (twogisLink != null && twogisLink.isNotEmpty)
      MapOption(label: '2ГИС', url: twogisLink),
    if (address.isNotEmpty)
      MapOption(
        label: 'Google Карты',
        url: 'https://www.google.com/maps/search/?api=1&query=$query',
      ),
    if (address.isNotEmpty)
      MapOption(
        label: 'Яндекс Карты',
        url: 'https://yandex.ru/maps/?text=$query',
      ),
    if (address.isNotEmpty && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
      MapOption(
        label: 'Apple Карты',
        url: 'https://maps.apple.com/?q=$query',
      ),
  ];
  return options;
}

/// Шторка выбора картографического приложения — вызывается по тапу на
/// кнопку «карты» в контактах профиля.
Future<void> showPiligrimMapPickerSheet(
  BuildContext context, {
  required List<MapOption> options,
  required Future<void> Function(String url) onLaunch,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (context) => _MapPickerSheet(options: options, onLaunch: onLaunch),
  );
}

class _MapPickerSheet extends StatelessWidget {
  const _MapPickerSheet({required this.options, required this.onLaunch});

  final List<MapOption> options;
  final Future<void> Function(String url) onLaunch;

  static const _surface = Color(0xFF1C1916);
  static const _divider = Color(0x14F2ECE1);

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad > 0 ? 0 : 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border.all(
              color: PiligrimColors.sky.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: PiligrimColors.sky.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Открыть в приложении',
                  style: PiligrimTextStyles.caption.copyWith(
                    color: PiligrimColors.sky.withValues(alpha: 0.42),
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Divider(height: 0.5, thickness: 0.5, color: _divider),
                for (final option in options)
                  PiligrimTap(
                    onTap: () {
                      Navigator.of(context).pop();
                      onLaunch(option.url);
                    },
                    borderRadius: BorderRadius.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/images/map_pin_generic.svg',
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              PiligrimColors.steppe.withValues(alpha: 0.75),
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            option.label,
                            style: PiligrimTextStyles.body.copyWith(
                              fontSize: 15,
                              color: PiligrimColors.sky.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
