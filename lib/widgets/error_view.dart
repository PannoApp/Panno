import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';

/// Полноэкранный виджет ошибки с тотем-иконкой и кнопкой «Попробовать снова».
/// Используется на всех экранах при сетевых ошибках и ошибках сервера.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/stone.svg',
              width: 64,
              height: 64,
              colorFilter: ColorFilter.mode(
                PiligrimColors.water.withValues(alpha: 0.4),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: PiligrimTextStyles.body.copyWith(
                color: PiligrimColors.sky.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: PiligrimColors.water,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: PiligrimColors.water.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Text(
                'Попробовать снова',
                style: PiligrimTextStyles.caption.copyWith(
                  color: PiligrimColors.water,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sliver-обёртка ErrorView для использования внутри CustomScrollView.
class SliverErrorView extends StatelessWidget {
  const SliverErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: ErrorView(message: message, onRetry: onRetry),
    );
  }
}
