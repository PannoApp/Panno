import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';

enum PiligrimToastType { info, success, error }

class _ToastRequest {
  final BuildContext context;
  final String message;
  final PiligrimToastType type;
  final Duration duration;

  _ToastRequest({
    required this.context,
    required this.message,
    required this.type,
    required this.duration,
  });
}

class PiligrimToast {
  static final List<_ToastRequest> _queue = [];
  static bool _isShowing = false;
  static OverlayEntry? _entry;
  static Timer? _timer;
  static final _key = GlobalKey<_ToastWidgetState>();

  static void show(
    BuildContext context,
    String message, {
    PiligrimToastType type = PiligrimToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _queue.add(_ToastRequest(
      context: context,
      message: message,
      type: type,
      duration: duration,
    ));
    if (!_isShowing) {
      _showNext();
    }
  }

  static void _showNext() {
    if (_queue.isEmpty) {
      _isShowing = false;
      return;
    }
    _isShowing = true;
    final request = _queue.first;

    if (!request.context.mounted) {
      _queue.removeAt(0);
      _showNext();
      return;
    }

    final overlay = Overlay.of(request.context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        key: _key,
        message: request.message,
        type: request.type,
        onAnimatedDismiss: _animatedDismiss,
        onDismissed: () {
          _cancelTimer();
          _entry?.remove();
          _entry = null;
          if (_queue.isNotEmpty) {
            _queue.removeAt(0);
          }
          _showNext();
        },
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(request.duration, _animatedDismiss);
  }

  static void _animatedDismiss() {
    _cancelTimer();
    _key.currentState?.animateOut().then((_) {
      _entry?.remove();
      _entry = null;
      if (_queue.isNotEmpty) {
        _queue.removeAt(0);
      }
      _showNext();
    });
  }

  static void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final PiligrimToastType type;
  final VoidCallback onAnimatedDismiss;
  final VoidCallback onDismissed;

  const _ToastWidget({
    super.key,
    required this.message,
    required this.type,
    required this.onAnimatedDismiss,
    required this.onDismissed,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 280),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );
    _ctrl.forward();
  }

  Future<void> animateOut() async {
    if (mounted) await _ctrl.reverse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _accent => switch (widget.type) {
        PiligrimToastType.error => PiligrimColors.fruit,
        PiligrimToastType.success => PiligrimColors.success,
        PiligrimToastType.info => PiligrimColors.water,
      };

  IconData get _icon => switch (widget.type) {
        PiligrimToastType.error => Icons.error_outline_rounded,
        PiligrimToastType.success => Icons.check_circle_outline_rounded,
        PiligrimToastType.info => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: Dismissible(
              key: ValueKey(widget.message),
              direction: DismissDirection.horizontal,
              onDismissed: (_) => widget.onDismissed(),
              child: Dismissible(
                key: ValueKey('${widget.message}_up'),
                direction: DismissDirection.up,
                onDismissed: (_) => widget.onDismissed(),
                child: Container(
                  margin: EdgeInsets.fromLTRB(16, safeTop + 10, 16, 0),
                  decoration: BoxDecoration(
                    borderRadius: PiligrimRadius.cardAll,
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.10),
                        blurRadius: 24,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                      ...PiligrimShadows.card,
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: PiligrimRadius.cardAll,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: PiligrimColors.earthDeep.withValues(alpha: 0.72),
                          borderRadius: PiligrimRadius.cardAll,
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.28),
                            width: 1,
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(2),
                                    bottomLeft: Radius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                child: Icon(_icon, color: _accent, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  child: Text(
                                    widget.message,
                                    style: PiligrimTextStyles.body.copyWith(
                                      fontSize: 14,
                                      height: 1.45,
                                      color: PiligrimColors.sky,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
