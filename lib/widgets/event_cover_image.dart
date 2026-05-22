import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'piligrim_shimmer.dart';

/// Сетевой URL (http/https) или путь к asset (`assets/...`).
bool piligrimImageIsNetwork(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

/// Кадр из CDN или локального asset — для новостей и фотоотчётов.
class PiligrimNetworkOrAssetImage extends StatelessWidget {
  const PiligrimNetworkOrAssetImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
  });

  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    if (piligrimImageIsNetwork(source)) {
      return CachedNetworkImage(
        imageUrl: source,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        placeholder: (_, __) => const PiligrimShimmer(),
        errorWidget: (_, __, ___) => const ColoredBox(color: PiligrimColors.earthDeep),
      );
    }
    return Image.asset(
      source,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          const ColoredBox(color: PiligrimColors.earthDeep),
    );
  }
}

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
        placeholder: (_, __) => const PiligrimShimmer(),
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
