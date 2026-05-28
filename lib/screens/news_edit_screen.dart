import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/events_news_data.dart';

/// Экран создания / редактирования новости.
/// [news] == null → режим создания новой новости.
class NewsEditScreen extends StatefulWidget {
  const NewsEditScreen({super.key, required this.news});

  final PiligrimNewsPost? news;

  @override
  State<NewsEditScreen> createState() => _NewsEditScreenState();
}

class _NewsEditScreenState extends State<NewsEditScreen> {
  bool get _isCreating => widget.news == null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      appBar: AppBar(
        backgroundColor: PiligrimColors.earthDeep,
        foregroundColor: PiligrimColors.sky,
        elevation: 0,
        title: Text(
          _isCreating ? 'Новая новость' : 'Редактировать',
          style: PiligrimTextStyles.heading.copyWith(
            fontSize: 18,
            color: PiligrimColors.sky,
          ),
        ),
      ),
      body: Center(
        child: Text(
          'TODO: форма новости',
          style: PiligrimTextStyles.body.copyWith(
            color: PiligrimColors.sky.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
