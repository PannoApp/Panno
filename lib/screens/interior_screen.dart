// Интерьер ресторана — галерея пространства (tab).
import 'package:flutter/material.dart';
import '../core/interior_assets.dart';
import '../core/theme.dart';
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
    final images = PiligrimInteriorAssets.allInteriorPngs;
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
                          'Тёплый свет, дерево и тишина — атмосфера Modern Nomad.',
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
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final path = images[i];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            path,
                            fit: BoxFit.cover,
                            cacheWidth: cacheW,
                          ),
                        );
                      },
                      childCount: images.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
