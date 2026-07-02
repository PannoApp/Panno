import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Полноэкранное спокойное состояние «контент временно недоступен».
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.title = _kDefaultTitle,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  static const String _kDefaultTitle = 'Временно недоступно';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: _PiligrimErrorBody(
          title: title,
          message: message,
          onRetry: onRetry,
          layout: _PiligrimErrorLayout.fullscreen,
        ),
      ),
    );
  }
}

/// Лёгкое atmospheric notice — home, interior, архив, фотоотчёт.
class PiligrimInlineError extends StatelessWidget {
  const PiligrimInlineError({
    super.key,
    this.title,
    required this.message,
    required this.onRetry,
  });

  final String? title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _PiligrimErrorBody(
      title: title,
      message: message,
      onRetry: onRetry,
      layout: _PiligrimErrorLayout.inline,
    );
  }
}

enum _PiligrimErrorLayout { fullscreen, inline }

class _PiligrimErrorBody extends StatelessWidget {
  const _PiligrimErrorBody({
    required this.title,
    required this.message,
    required this.onRetry,
    required this.layout,
  });

  final String? title;
  final String message;
  final VoidCallback onRetry;
  final _PiligrimErrorLayout layout;

  bool get _isFullscreen => layout == _PiligrimErrorLayout.fullscreen;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle =
        title ?? (_isFullscreen ? ErrorView._kDefaultTitle : null);

    final titleStyle = (_isFullscreen
            ? PiligrimTextStyles.heading
            : PiligrimTextStyles.caption)
        .copyWith(
      color: PiligrimColors.sky.withValues(
        alpha: _isFullscreen ? 0.88 : 0.55,
      ),
      fontSize: _isFullscreen ? 17 : 10,
      fontWeight: _isFullscreen ? FontWeight.w700 : FontWeight.w300,
      letterSpacing: _isFullscreen ? 0.4 : 1.8,
      height: 1.35,
    );

    final messageStyle = PiligrimTextStyles.body.copyWith(
      color: PiligrimColors.sky.withValues(alpha: _isFullscreen ? 0.5 : 0.42),
      fontSize: _isFullscreen ? 14 : 12.5,
      height: 1.5,
      fontWeight: FontWeight.w300,
    );

    final accent = _SignalLossMark(
      width: _isFullscreen ? 28 : 20,
      opacity: _isFullscreen ? 0.22 : 0.14,
    );

    final titleWidget = resolvedTitle == null
        ? null
        : Text(
            resolvedTitle,
            textAlign: _isFullscreen ? TextAlign.center : TextAlign.start,
            style: titleStyle,
          );

    final messageWidget = Text(
      message,
      textAlign: _isFullscreen ? TextAlign.center : TextAlign.start,
      style: messageStyle,
    );

    final retry = _PiligrimRetryAction(
      onPressed: onRetry,
      compact: !_isFullscreen,
    );

    if (_isFullscreen) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          accent,
          const SizedBox(height: 28),
          if (titleWidget != null) ...[
            titleWidget,
            const SizedBox(height: 10),
          ],
          messageWidget,
          const SizedBox(height: 32),
          retry,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: PiligrimColors.sky.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (titleWidget != null) ...[
                        titleWidget,
                        const SizedBox(height: 4),
                      ],
                      messageWidget,
                      const SizedBox(height: 6),
                      retry,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Едва заметная «разорванная» линия — сигнал недоступности без иконки.
class _SignalLossMark extends StatelessWidget {
  const _SignalLossMark({
    required this.width,
    required this.opacity,
  });

  final double width;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final color = PiligrimColors.water.withValues(alpha: opacity);
    const gap = 5.0;
    final segment = (width - gap) / 2;

    return SizedBox(
      width: width,
      height: 1,
      child: Row(
        children: [
          Container(width: segment, height: 1, color: color),
          SizedBox(width: gap),
          Container(width: segment, height: 1, color: color),
        ],
      ),
    );
  }
}

class _PiligrimRetryAction extends StatelessWidget {
  const _PiligrimRetryAction({
    required this.onPressed,
    required this.compact,
  });

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = PiligrimTextStyles.caption.copyWith(
      color: PiligrimColors.water.withValues(alpha: 0.85),
      letterSpacing: compact ? 0.8 : 1.0,
      fontSize: compact ? 11.5 : 12,
      fontWeight: FontWeight.w300,
      decoration: TextDecoration.underline,
      decorationColor: PiligrimColors.water.withValues(alpha: 0.35),
    );

    return Align(
      alignment: compact ? Alignment.centerLeft : Alignment.center,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: PiligrimColors.water,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 4,
            vertical: compact ? 0 : 2,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          overlayColor: PiligrimColors.water.withValues(alpha: 0.06),
        ),
        child: Text('Повторить', style: style),
      ),
    );
  }
}

/// Sliver-обёртка [ErrorView] для использования внутри CustomScrollView.
class SliverErrorView extends StatelessWidget {
  const SliverErrorView({
    super.key,
    this.title,
    required this.message,
    required this.onRetry,
  });

  final String? title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: ErrorView(
        title: title ?? ErrorView._kDefaultTitle,
        message: message,
        onRetry: onRetry,
      ),
    );
  }
}
