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
  // Свой GlobalKey на каждый показанный тост (не общий статический) —
  // общий ключ ломал очередь: при быстрой смене одного тоста на следующий
  // (сразу remove() старого entry + insert() нового в одном и том же
  // вызове) Flutter иногда на мгновение видит два элемента с одним и тем
  // же GlobalKey и кидает исключение — а оно молча проглатывалось в
  // try/catch ниже, поэтому второй и третий тост из очереди просто не
  // появлялись, без видимой ошибки.
  static GlobalKey<_ToastWidgetState>? _currentKey;

  static void show(
    BuildContext context,
    String message, {
    PiligrimToastType type = PiligrimToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    debugPrint('[PiligrimToast] show() called, message: "$message", queue length before: ${_queue.length}, isShowing: $_isShowing');
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
    debugPrint('[PiligrimToast] _showNext() called, queue length: ${_queue.length}');
    if (_queue.isEmpty) {
      _isShowing = false;
      debugPrint('[PiligrimToast] Queue is empty, resetting isShowing to false');
      return;
    }
    _isShowing = true;
    final request = _queue.first;

    if (!request.context.mounted) {
      debugPrint('[PiligrimToast] Context not mounted, skipping this request');
      _queue.removeAt(0);
      _showNext();
      return;
    }

    try {
      final overlay = Overlay.of(request.context, rootOverlay: true);
      debugPrint('[PiligrimToast] Overlay found: $overlay');
      final key = GlobalKey<_ToastWidgetState>();
      _currentKey = key;
      _entry = OverlayEntry(
        builder: (_) => _ToastWidget(
          key: key,
          message: request.message,
          type: request.type,
          onAnimatedDismiss: _animatedDismiss,
          onDismissed: () {
            debugPrint('[PiligrimToast] onDismissed called from widget gesture');
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
      debugPrint('[PiligrimToast] Overlay entry inserted successfully');
      _timer = Timer(request.duration, _animatedDismiss);
    } catch (e, stack) {
      debugPrint('[PiligrimToast] Exception in _showNext: $e\n$stack');
    }
  }

  static void _animatedDismiss() {
    _cancelTimer();
    final state = _currentKey?.currentState;
    if (state != null && state.mounted) {
      state.animateOut().then((_) {
        _removeEntryAndShowNext();
      });
    } else {
      _removeEntryAndShowNext();
    }
  }

  static void _removeEntryAndShowNext() {
    _entry?.remove();
    _entry = null;
    if (_queue.isNotEmpty) {
      _queue.removeAt(0);
    }
    _showNext();
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
        // error/success оставлены как есть — это универсальная сигнальная
        // семантика (красный/зелёный), трогать её ради «теплоты» вредно для
        // читаемости. info — самый частый, «нейтральный» тип (дефолт у
        // show()), и раньше был холодным water; steppe (тёплое золото —
        // основной акцент бренда на CTA/выборе) делает обычные тосты
        // заметно менее «стандартными».
        PiligrimToastType.error => PiligrimColors.fruit,
        PiligrimToastType.success => PiligrimColors.success,
        PiligrimToastType.info => PiligrimColors.steppe,
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
                        color: _accent.withValues(alpha: 0.18),
                        blurRadius: 28,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
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
                          // earthDeep — самый тёмный тон в палитре, почти
                          // не отличим от текстурного фона приложения на
                          // глаз — тост сливался с экраном под ним. surfaceClay
                          // заметно светлее (и всё ещё тёплый, «глиняный»
                          // тон из той же палитры), плюс выше непрозрачность —
                          // карточка теперь читается как отдельный,
                          // приподнятый над контентом слой.
                          color: PiligrimColors.surfaceClay.withValues(alpha: 0.94),
                          borderRadius: PiligrimRadius.cardAll,
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.45),
                            width: 1.3,
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
