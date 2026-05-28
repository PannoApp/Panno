import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models/api_event_photo.dart';
import '../widgets/piligrim_tap.dart';
import 'event_cover_image.dart';

class EventPhotoReportGallery extends StatefulWidget {
  const EventPhotoReportGallery({
    super.key,
    required this.photos,
    this.isAdmin = false,
    this.onDeletePhoto,
  });

  final List<ApiEventPhoto> photos;
  final bool isAdmin;
  /// Вызывается когда администратор нажимает удалить фото.
  final void Function(ApiEventPhoto photo)? onDeletePhoto;

  @override
  State<EventPhotoReportGallery> createState() =>
      _EventPhotoReportGalleryState();
}

class _EventPhotoReportGalleryState extends State<EventPhotoReportGallery> {
  final PageController _controller =
      PageController(viewportFraction: 0.92);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _preload(int index) {
    for (final offset in [-1, 1]) {
      final i = index + offset;
      if (i >= 0 && i < widget.photos.length) {
        final src = widget.photos[i].imageUrl;
        if (piligrimImageIsNetwork(src)) {
          precacheImage(CachedNetworkImageProvider(src), context);
        } else {
          precacheImage(AssetImage(src), context);
        }
      }
    }
  }

  void _confirmDelete(ApiEventPhoto photo) {
    showDialog<void>(
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Отмена',
                style: PiligrimTextStyles.button
                    .copyWith(color: PiligrimColors.water)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onDeletePhoto?.call(photo);
            },
            child: Text('Удалить',
                style: PiligrimTextStyles.button
                    .copyWith(color: PiligrimColors.fruit)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: _preload,
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PiligrimNetworkOrAssetImage(
                    source: photo.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                  ),
                  // Кнопка удаления — только для администратора
                  if (widget.isAdmin)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: PiligrimTap(
                        onTap: () => _confirmDelete(photo),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                PiligrimColors.earthDeep.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: PiligrimColors.fruit.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: PiligrimColors.fruit, size: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
