import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/models/api_event.dart';

/// Экран создания / редактирования мероприятия.
/// [event] == null → режим создания нового мероприятия.
class EventEditScreen extends StatefulWidget {
  const EventEditScreen({super.key, required this.event});

  final ApiEvent? event;

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  bool get _isCreating => widget.event == null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      appBar: AppBar(
        backgroundColor: PiligrimColors.earthDeep,
        foregroundColor: PiligrimColors.sky,
        elevation: 0,
        title: Text(
          _isCreating ? 'Новое мероприятие' : 'Редактировать',
          style: PiligrimTextStyles.heading.copyWith(
            fontSize: 18,
            color: PiligrimColors.sky,
          ),
        ),
      ),
      body: Center(
        child: Text(
          'TODO: форма мероприятия',
          style: PiligrimTextStyles.body.copyWith(
            color: PiligrimColors.sky.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
