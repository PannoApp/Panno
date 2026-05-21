import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/models/api_event_photo.dart';
import 'event_cover_image.dart';

class EventPhotoReportGallery extends StatefulWidget {
  const EventPhotoReportGallery({super.key, required this.photos});

  final List<ApiEventPhoto> photos;

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
              child: PiligrimNetworkOrAssetImage(
                source: photo.imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 800,
              ),
            ),
          );
        },
      ),
    );
  }
}
