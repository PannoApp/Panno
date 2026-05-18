// Интерьер ресторана — галерея пространства (tab).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/interior_assets.dart';
import '../core/theme.dart';
import '../data/models/interior_slide.dart';
import '../providers/core_info_provider.dart';
import '../widgets/piligrim_background.dart';

class InteriorScreen extends StatefulWidget {
  const InteriorScreen({super.key});

  @override
  State<InteriorScreen> createState() => _InteriorScreenState();
}

class _InteriorScreenState extends State<InteriorScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<CoreInfoProvider>(
      builder: (context, core, _) {
        final slides = core.interiorSlides;
        final useApi = slides.isNotEmpty;
        final assetPaths = PiligrimInteriorAssets.allInteriorPngs;
        final itemCount = useApi ? slides.length : assetPaths.length;
        final cacheW = PiligrimInteriorAssets.decodeCacheWidth(context);

        return Scaffold(
          backgroundColor: const Color(0xFF1E1B19),
          body: Stack(
            children: [
              const Positioned.fill(child: PiligrimBackground(cinematic: true)),
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ИНТЕРЬЕР',
                              style: PiligrimTextStyles.sectionLabel.copyWith(
                                letterSpacing: 2.8,
                                color: PiligrimColors.sky.withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Пространство PILIGRIM',
                              style: PiligrimTextStyles.heading.copyWith(
                                fontSize: 24,
                                color: PiligrimColors.sky,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              useApi
                                  ? 'Кадры залов и зон — с сервера ресторана.'
                                  : 'Тёплый свет, дерево и тишина — атмосфера Modern Nomad.',
                              style: PiligrimTextStyles.body.copyWith(
                                fontSize: 13,
                                height: 1.55,
                                color: PiligrimColors.sky.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (core.isLoading && !useApi)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: PiligrimColors.water,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            if (useApi) {
                              return _InteriorSlideTile(
                                slide: slides[i],
                                cacheWidth: cacheW,
                              );
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                assetPaths[i],
                                fit: BoxFit.cover,
                                cacheWidth: cacheW,
                              ),
                            );
                          },
                          childCount: itemCount,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InteriorSlideTile extends StatelessWidget {
  const _InteriorSlideTile({
    required this.slide,
    required this.cacheWidth,
  });

  final InteriorSlide slide;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: slide.imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: cacheWidth,
            placeholder: (_, __) =>
                const ColoredBox(color: PiligrimColors.earthDeep),
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: PiligrimColors.earthDeep),
          ),
          if (slide.zoneDisplay.isNotEmpty)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                slide.zoneDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PiligrimTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: PiligrimColors.sky.withValues(alpha: 0.9),
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
