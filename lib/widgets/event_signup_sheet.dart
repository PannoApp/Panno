import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/events_provider.dart';
import 'piligrim_tap.dart';

Future<void> showEventSignupSheet(
  BuildContext context, {
  required int eventId,
  required String eventTitle,
}) {
  final events = context.read<EventsProvider>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (ctx) => ChangeNotifierProvider<EventsProvider>.value(
      value: events,
      child: _EventSignupSheet(
        eventId: eventId,
        eventTitle: eventTitle,
      ),
    ),
  );
}

class _EventSignupSheet extends StatefulWidget {
  const _EventSignupSheet({
    required this.eventId,
    required this.eventTitle,
  });

  final int eventId;
  final String eventTitle;

  @override
  State<_EventSignupSheet> createState() => _EventSignupSheetState();
}

class _EventSignupSheetState extends State<_EventSignupSheet> {
  int _guestsCount = 1;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_guestsCount < 1) return;

    setState(() => _submitting = true);
    try {
      await context.read<EventsProvider>().reserveEvent(
            widget.eventId,
            _guestsCount,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Вы записаны на «${widget.eventTitle}». Подтверждение придёт от ресторана.',
            style: PiligrimTextStyles.body.copyWith(fontSize: 14),
          ),
          backgroundColor: PiligrimColors.earth,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final err = context.read<EventsProvider>().reserveError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err ?? 'Не удалось записаться. Попробуйте позже.',
            style: PiligrimTextStyles.body.copyWith(fontSize: 14),
          ),
          backgroundColor: PiligrimColors.earthDeep,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PiligrimColors.earthDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: PiligrimColors.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PiligrimColors.sky.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Запись на мероприятие',
                  style: PiligrimTextStyles.heading.copyWith(
                    color: PiligrimColors.sky,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.eventTitle,
                  style: PiligrimTextStyles.caption.copyWith(
                    color: PiligrimColors.water,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Количество гостей',
                  style: PiligrimTextStyles.caption.copyWith(
                    color: PiligrimColors.sky.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _guestsCount > 1 && !_submitting
                          ? () => setState(() => _guestsCount--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: PiligrimColors.water,
                    ),
                    Text(
                      '$_guestsCount',
                      style: PiligrimTextStyles.title.copyWith(
                        fontSize: 28,
                        color: PiligrimColors.sky,
                      ),
                    ),
                    IconButton(
                      onPressed: !_submitting
                          ? () => setState(() => _guestsCount++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: PiligrimColors.water,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Имя и телефон берутся из вашего профиля.',
                  textAlign: TextAlign.center,
                  style: PiligrimTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: PiligrimColors.sky.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: PiligrimTap(
                    onTap: _submitting || _guestsCount < 1 ? null : _submit,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: PiligrimColors.water,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _submitting ? 'Отправляем…' : 'ЗАПИСАТЬСЯ',
                        style: PiligrimTextStyles.button.copyWith(
                          fontSize: 15,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Auth guard для записи: sheet → login → sheet снова не открывается автоматически.
Future<void> showEventSignupWithAuth(
  BuildContext context, {
  required int eventId,
  required String eventTitle,
  required Future<bool> Function() ensureAuth,
}) async {
  if (!await ensureAuth()) return;
  if (!context.mounted) return;
  await showEventSignupSheet(
    context,
    eventId: eventId,
    eventTitle: eventTitle,
  );
}
