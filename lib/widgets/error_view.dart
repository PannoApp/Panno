import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';

/// Полноэкранный виджет ошибки с тотем-иконкой и кнопкой «Повторить».
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
        child: _PiligrimErrorContent(
          message: message,
          onRetry: onRetry,
          iconSize: 64,
          compact: false,
        ),
      ),
    );
  }
}

/// Компактный inline-блок для degraded-состояния (home, interior, архив, фотоотчёт).
class PiligrimInlineError extends StatelessWidget {
  const PiligrimInlineError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PiligrimColors.earthDeep.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PiligrimColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: _PiligrimErrorContent(
          message: message,
          onRetry: onRetry,
          iconSize: 36,
          compact: true,
        ),
      ),
    );
  }
}

class _PiligrimErrorContent extends StatelessWidget {
  const _PiligrimErrorContent({
    required this.message,
    required this.onRetry,
    required this.iconSize,
    required this.compact,
  });

  final String message;
  final VoidCallback onRetry;
  final double iconSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final messageStyle = PiligrimTextStyles.body.copyWith(
      color: PiligrimColors.sky.withValues(alpha: 0.6),
      fontSize: compact ? 13 : 14,
      height: 1.45,
    );

    final retryButton = TextButton(
      onPressed: onRetry,
      style: TextButton.styleFrom(
        foregroundColor: PiligrimColors.water,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 20 : 28,
          vertical: compact ? 8 : 12,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: PiligrimColors.water.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: Text(
        'Повторить',
        style: PiligrimTextStyles.caption.copyWith(
          color: PiligrimColors.water,
          letterSpacing: 1.2,
          fontSize: 12,
        ),
      ),
    );

    final icon = SvgPicture.asset(
      'assets/images/stone.svg',
      width: iconSize,
      height: iconSize,
      colorFilter: ColorFilter.mode(
        PiligrimColors.water.withValues(alpha: 0.4),
        BlendMode.srcIn,
      ),
    );

    final messageWidget = Text(
      message,
      textAlign: compact ? TextAlign.start : TextAlign.center,
      style: messageStyle,
    );

    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                messageWidget,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: retryButton),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 20),
        messageWidget,
        const SizedBox(height: 24),
        retryButton,
      ],
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
