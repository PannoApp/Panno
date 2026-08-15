// Типографика под hero — на textured background, не на фотографии.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/home_data.dart';
import '../providers/core_info_provider.dart';

class HomeHeroIntroBlock extends StatelessWidget {
  const HomeHeroIntroBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final coreInfo = context.watch<CoreInfoProvider>().coreInfo;
    final concept = coreInfo?.conceptDescription ?? kModernNomadConcept;
    final conceptKz = coreInfo?.conceptDescriptionKz;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Без hairline (flutter-dev): только воздух между hero и текстом.
          const SizedBox(height: 32),
          SvgPicture.asset(
            'assets/images/piligrim.svg',
            height: 42,
            colorFilter: const ColorFilter.mode(
              PiligrimColors.sky,
              BlendMode.srcIn,
            ),
          )
              .animate()
              .fadeIn(duration: 1100.ms, curve: Curves.easeOut),

          const SizedBox(height: 36),

          // Заголовок теперь статичный (раньше ротировались 3 фразы) —
          // kHeroTitle уже совпадает с первыми предложениями нового текста.
          Text(
            kHeroTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PiligrimTextStyles.display.copyWith(
              fontSize: 28,
              height: 1.18,
              color: PiligrimColors.sky,
              letterSpacing: 0.2,
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 1200.ms, curve: Curves.easeOut),

          const SizedBox(height: 18),

          Text(
            concept,
            style: PiligrimTextStyles.body.copyWith(
              fontSize: 13.5,
              height: 1.6,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.35,
              color: PiligrimColors.sky.withValues(alpha: 0.78),
            ),
          )
              .animate()
              .fadeIn(delay: 420.ms, duration: 1000.ms, curve: Curves.easeOut),

          // Казахский блок — только если перевод заполнен на бэкенде
          // (RestaurantInfo.concept_description_kz). Пока перевода нет,
          // блок просто не рендерится.
          if (conceptKz != null && conceptKz.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              conceptKz,
              style: PiligrimTextStyles.body.copyWith(
                fontSize: 13.5,
                height: 1.6,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.35,
                color: PiligrimColors.sky.withValues(alpha: 0.6),
              ),
            )
                .animate()
                .fadeIn(delay: 560.ms, duration: 1000.ms, curve: Curves.easeOut),
          ],
        ],
      ),
    );
  }
}
