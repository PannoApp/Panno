// Полноэкранный просмотр QR-кода карты лояльности — крупнее и проще
// отсканировать на кассе, чем маленькую плитку на «Профиле».
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../core/theme.dart';
import '../widgets/piligrim_nav_button.dart';

/// Открывается через [PiligrimPageRoute]. Свайп вниз или крестик — закрыть.
class LoyaltyQrViewer extends StatefulWidget {
  const LoyaltyQrViewer({
    super.key,
    required this.url,
    required this.tint,
  });

  final String url;
  final List<double> tint;

  @override
  State<LoyaltyQrViewer> createState() => _LoyaltyQrViewerState();
}

class _LoyaltyQrViewerState extends State<LoyaltyQrViewer> {
  double _dragOffset = 0;
  double _bgOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    // Максимальная яркость только для этого экрана — так проще
    // отсканировать код на кассе даже в тёмном зале. Не поддерживается на
    // некоторых платформах (например, десктоп) — молча игнорируем.
    ScreenBrightness().setApplicationScreenBrightness(1.0).catchError((_) {});
  }

  @override
  void dispose() {
    ScreenBrightness().resetApplicationScreenBrightness().catchError((_) {});
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy <= 0 && _dragOffset <= 0) return;
    setState(() {
      _dragOffset += details.delta.dy;
      if (_dragOffset < 0) _dragOffset = 0;
      _bgOpacity = (1.0 - (_dragOffset / 150)).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final vel = details.velocity.pixelsPerSecond.dy;
    if (vel > 400 || _dragOffset > 100) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0;
        _bgOpacity = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final size = (MediaQuery.sizeOf(context).width - 96).clamp(200.0, 320.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _bgOpacity,
              duration: Duration.zero,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: PiligrimColors.nomadCream,
                        borderRadius: PiligrimRadius.lgAll,
                        boxShadow: [
                          BoxShadow(
                            color: PiligrimColors.shadow.withValues(alpha: 0.4),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: CachedNetworkImage(
                        imageUrl: widget.url,
                        width: size,
                        height: size,
                        fit: BoxFit.contain,
                        imageBuilder: (context, imageProvider) => ColorFiltered(
                          colorFilter: ColorFilter.matrix(widget.tint),
                          child: Image(
                            image: imageProvider,
                            width: size,
                            height: size,
                            fit: BoxFit.contain,
                          ),
                        ),
                        placeholder: (context, _) => SizedBox(
                          width: size,
                          height: size,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: PiligrimColors.textDark,
                            ),
                          ),
                        ),
                        errorWidget: (context, _, __) => SizedBox(
                          width: size,
                          height: size,
                          child: Center(
                            child: Icon(
                              Icons.qr_code_2_rounded,
                              size: 40,
                              color: PiligrimColors.textDark
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Покажите QR-код на кассе',
                      style: PiligrimTextStyles.body.copyWith(
                        fontSize: 13,
                        color: PiligrimColors.sky.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + 8,
            left: 8,
            child: PiligrimNavButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 220.ms).scale(
            begin: const Offset(0.94, 0.94),
            end: const Offset(1.0, 1.0),
            duration: 300.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}
