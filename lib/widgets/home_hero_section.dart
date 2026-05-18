// Hero — только интерьер: затемнение и альфа-растворение внутри кадра.
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/interior_assets.dart';

class CrossfadingHeroInterior extends StatefulWidget {
  const CrossfadingHeroInterior({
    super.key,
    required this.paths,
    required this.index,
    required this.cacheWidth,
    required this.cacheHeight,
  });

  final List<String> paths;
  final int index;
  final int cacheWidth;
  final int cacheHeight;

  @override
  State<CrossfadingHeroInterior> createState() => _CrossfadingHeroInteriorState();
}

class _CrossfadingHeroInteriorState extends State<CrossfadingHeroInterior>
    with SingleTickerProviderStateMixin {
  late int _from;
  late int _to;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    final len = widget.paths.length;
    final i = len == 0 ? 0 : widget.index % len;
    _from = i;
    _to = i;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant CrossfadingHeroInterior oldWidget) {
    super.didUpdateWidget(oldWidget);
    final len = widget.paths.length;
    if (len == 0) return;
    final newIdx = widget.index % len;
    final oldIdx = oldWidget.index % len;
    if (newIdx != oldIdx) {
      _from = oldIdx;
      _to = newIdx;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final len = widget.paths.length;
    if (len == 0) return const SizedBox.expand();

    Widget shot(int i) {
      return Image.asset(
        widget.paths[i % len],
        fit: BoxFit.cover,
        alignment: const Alignment(0.0, 0.14),
        isAntiAlias: true,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = Curves.easeInOutCubic.transform(_ctrl.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: 1 - t, child: shot(_from)),
            Opacity(opacity: t, child: shot(_to)),
          ],
        );
      },
    );
  }
}

/// Только фото — fade и затемнение внутри кадра; снизу просвечивает PiligrimBackground.
class HomeHeroSection extends StatefulWidget {
  const HomeHeroSection({
    super.key,
    required this.height,
    required this.scrollOffset,
    required this.tiltX,
    required this.tiltY,
  });

  final double height;
  final double scrollOffset;
  final double tiltX;
  final double tiltY;

  @override
  State<HomeHeroSection> createState() => _HomeHeroSectionState();
}

class _HomeHeroSectionState extends State<HomeHeroSection> {
  int _heroVisualIndex = 0;
  late Timer _heroVisualTimer;

  static const double _heroImageScrollParallax = 0.10;
  static const double _heroImageScale = 1.26;
  static const _heroVisuals = PiligrimInteriorAssets.homeHeroCycle;

  /// Затемнение только в нижних ~22% — верх и середина без overlay.
  static const _warmInteriorDarken = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0x00000000),
      Color(0x00000000),
      Color(0x0A211D1A),
      Color(0x1A211D1A),
      Color(0x301E1B19),
      Color(0x501E1B19),
      Color(0x781E1B19),
      Color(0xA81E1B19),
      Color(0xD01E1B19),
    ],
    stops: [0.0, 0.72, 0.78, 0.83, 0.87, 0.91, 0.94, 0.96, 0.98, 1.0],
  );

  /// Альфа-растворение — только нижняя четверть hero.
  static Shader _photoDissolveShader(Rect bounds) {
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [
        0.0,
        0.76,
        0.80,
        0.84,
        0.88,
        0.91,
        0.94,
        0.96,
        0.98,
        1.0,
      ],
      colors: [
        Color(0xFFFFFFFF),
        Color(0xFFFFFFFF),
        Color(0xF0FFFFFF),
        Color(0xC8FFFFFF),
        Color(0x88FFFFFF),
        Color(0x50FFFFFF),
        Color(0x28FFFFFF),
        Color(0x10FFFFFF),
        Color(0x04FFFFFF),
        Color(0x00FFFFFF),
      ],
    ).createShader(bounds);
  }

  @override
  void initState() {
    super.initState();
    _heroVisualTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) return;
      setState(() => _heroVisualIndex = (_heroVisualIndex + 1) % _heroVisuals.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cw = PiligrimInteriorAssets.decodeCacheWidth(context);
      final ch = PiligrimInteriorAssets.decodeCacheHeight(context, widget.height);
      for (final p in _heroVisuals) {
        precacheImage(
          ResizeImage(AssetImage(p), width: cw, height: ch),
          context,
        );
      }
    });
  }

  @override
  void dispose() {
    _heroVisualTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRect(
        child: ShaderMask(
          shaderCallback: _photoDissolveShader,
          blendMode: BlendMode.dstIn,
          child: Transform.translate(
          offset: Offset(
            widget.tiltX * 8,
            widget.tiltY * 6 + widget.scrollOffset * _heroImageScrollParallax,
          ),
          child: Transform.scale(
            scale: _heroImageScale,
            alignment: const Alignment(0.0, 0.32),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CrossfadingHeroInterior(
                  paths: _heroVisuals,
                  index: _heroVisualIndex,
                  cacheWidth: PiligrimInteriorAssets.decodeCacheWidth(context),
                  cacheHeight: PiligrimInteriorAssets.decodeCacheHeight(
                    context,
                    widget.height * 1.18,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: _warmInteriorDarken),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
