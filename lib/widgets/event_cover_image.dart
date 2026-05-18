import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Обложка мероприятия: CDN или локальный fallback.
class EventCoverImage extends StatelessWidget {
  const EventCoverImage({
    super.key,
    this.imageUrl,
    required this.fallbackAsset,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final String fallbackAsset;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: (_, __) => const ColoredBox(color: PiligrimColors.earthDeep),
        errorWidget: (_, __, ___) => _asset(),
      );
    }
    return _asset();
  }

  Widget _asset() {
    if (fallbackAsset.isEmpty) {
      return const ColoredBox(color: PiligrimColors.earthDeep);
    }
    return Image.asset(fallbackAsset, fit: fit);
  }
}
