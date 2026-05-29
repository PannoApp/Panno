import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models/api_event.dart';
import '../data/models/api_event_photo.dart';
import '../data/repositories/events_repository.dart';
import '../providers/events_provider.dart';
import '../widgets/piligrim_loader.dart';
import '../widgets/piligrim_tap.dart';

/// Экран управления фотоотчётом прошедшего мероприятия.
/// Администратор может добавлять и удалять фотографии.
class EventPhotoReportScreen extends StatefulWidget {
  const EventPhotoReportScreen({super.key, required this.event});

  final ApiEvent event;

  @override
  State<EventPhotoReportScreen> createState() => _EventPhotoReportScreenState();
}

class _EventPhotoReportScreenState extends State<EventPhotoReportScreen> {
  final _repo = EventsRepository();
  List<ApiEventPhoto> _photos = const [];
  bool _isLoading = true;
  String? _error;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _photos = await _repo.fetchPhotoReport(widget.event.id);
    } catch (e) {
      _error = 'Не удалось загрузить фотоотчёт';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Кадрировать фото'),
        IOSUiSettings(title: 'Кадрировать фото'),
      ],
    );
    if (cropped == null) return;

    setState(() => _isUploading = true);
    try {
      final photo =
          await _repo.addPhotoToReport(widget.event.id, File(cropped.path));
      setState(() => _photos = [..._photos, photo]);
      // Обновляем флаг hasPhotoReport в провайдере
      if (mounted) context.read<EventsProvider>().loadArchived();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Не удалось загрузить фото',
              style:
                  PiligrimTextStyles.body.copyWith(color: PiligrimColors.sky)),
          backgroundColor: PiligrimColors.earthDeep,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _confirmDelete(ApiEventPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PiligrimColors.earthDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: PiligrimColors.divider),
        ),
        title: Text(
          'Удалить фото?',
          style:
              PiligrimTextStyles.heading.copyWith(color: PiligrimColors.sky),
        ),
        content: Text(
          'Фотография будет удалена из фотоотчёта.',
          style: PiligrimTextStyles.body
              .copyWith(color: PiligrimColors.sky.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена',
                style: PiligrimTextStyles.button
                    .copyWith(color: PiligrimColors.water)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Удалить',
                style: PiligrimTextStyles.button
                    .copyWith(color: PiligrimColors.fruit)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _repo.deletePhotoFromReport(widget.event.id, photo.id);
      setState(() => _photos = _photos.where((p) => p.id != photo.id).toList());
      if (mounted && _photos.isEmpty) {
        context.read<EventsProvider>().loadArchived();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Не удалось удалить фото',
              style:
                  PiligrimTextStyles.body.copyWith(color: PiligrimColors.sky)),
          backgroundColor: PiligrimColors.earthDeep,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 80,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: PiligrimTap(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 2, 8, 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 12,
                    color: PiligrimColors.sky.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Назад',
                    style: PiligrimTextStyles.caption.copyWith(
                      color: PiligrimColors.sky.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        title: Text(
          'Фотоотчёт',
          style: PiligrimTextStyles.heading
              .copyWith(fontSize: 17, color: PiligrimColors.sky),
        ),
        centerTitle: true,
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: PiligrimLoader(
                      size: 20, color: PiligrimColors.steppe)),
            )
          else
            PiligrimTap(
              onTap: _addPhoto,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Icon(Icons.add_photo_alternate_outlined,
                    color: PiligrimColors.water, size: 22),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                widget.event.title,
                style: PiligrimTextStyles.body.copyWith(
                  color: PiligrimColors.sky.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: _isUploading
          ? null
          : FloatingActionButton(
              backgroundColor: PiligrimColors.earthWarm,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: PiligrimColors.water.withValues(alpha: 0.35)),
              ),
              onPressed: _addPhoto,
              child: const Icon(Icons.add, color: PiligrimColors.water),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: PiligrimLoader(color: PiligrimColors.steppe));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style: PiligrimTextStyles.body.copyWith(
                    color: PiligrimColors.sky.withValues(alpha: 0.55))),
            const SizedBox(height: 16),
            PiligrimTap(
              onTap: _load,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: PiligrimColors.water.withValues(alpha: 0.4)),
                ),
                child: Text('Повторить',
                    style: PiligrimTextStyles.button
                        .copyWith(color: PiligrimColors.water)),
              ),
            ),
          ],
        ),
      );
    }
    if (_photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                color: PiligrimColors.sky.withValues(alpha: 0.2), size: 48),
            const SizedBox(height: 16),
            Text(
              'Нет фотографий',
              style: PiligrimTextStyles.body.copyWith(
                  color: PiligrimColors.sky.withValues(alpha: 0.45)),
            ),
            const SizedBox(height: 6),
            Text(
              'Нажмите + чтобы добавить фото в отчёт',
              style: PiligrimTextStyles.caption.copyWith(
                  color: PiligrimColors.sky.withValues(alpha: 0.30),
                  fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding:
          const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, i) {
        final photo = _photos[i];
        return _PhotoTile(
          photo: photo,
          onDelete: () => _confirmDelete(photo),
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.onDelete});

  final ApiEventPhoto photo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: photo.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => const ColoredBox(
              color: PiligrimColors.earthDeep,
            ),
            errorWidget: (_, __, ___) => const ColoredBox(
              color: PiligrimColors.earthDeep,
              child: Center(
                child: Icon(Icons.broken_image_outlined,
                    color: PiligrimColors.fruit, size: 28),
              ),
            ),
          ),
          // Тонкий overlay для читаемости кнопки удаления
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    PiligrimColors.earthDeep.withValues(alpha: 0.55),
                    PiligrimColors.earthDeep.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: PiligrimTap(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: PiligrimColors.earthDeep.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PiligrimColors.fruit.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: const Icon(Icons.close_rounded,
                    color: PiligrimColors.fruit, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
