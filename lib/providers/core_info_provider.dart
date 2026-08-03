import 'package:flutter/foundation.dart';

import '../core/dio_errors.dart';
import '../core/home_data.dart';
import '../data/models/core_info.dart';
import '../data/models/interior_slide.dart';
import '../data/repositories/core_repository.dart';

/// Публичные данные ресторана с API + fallback на mock.
class CoreInfoProvider extends ChangeNotifier {
  CoreInfoProvider({CoreRepository? repository})
      : _repository = repository ?? CoreRepository();

  final CoreRepository _repository;

  CoreInfo? coreInfo;
  List<InteriorSlide> interiorSlides = const [];
  bool isLoading = false;
  String? error;
  bool isOfflineMode = false;

  bool get isLoaded => coreInfo != null;
  bool get isOpenNow => coreInfo?.isOpenNow ?? kRestaurantInfo.isOpen;
  String get workingHoursDisplay =>
      coreInfo?.workingHours ?? kRestaurantInfo.hoursLabel;
  String? get workingHoursNote => coreInfo?.workingHoursNote;

  List<String> get heroImageUrls {
    final urls = coreInfo?.heroImageUrls ?? const [];
    if (urls.isNotEmpty) return urls;
    return const [];
  }

  bool get _isRepoOffline {
    try {
      return _repository.isOfflineMode;
    } catch (_) {
      return false;
    }
  }

  Future<void> load() async {
    if (isLoading || coreInfo != null) return;

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.fetchCoreInfo(),
        _repository.fetchInterior(),
      ]);
      coreInfo = results[0] as CoreInfo;
      interiorSlides = results[1] as List<InteriorSlide>;
      isOfflineMode = _isRepoOffline;
    } catch (e) {
      error = dioErrorMessage(e);
      coreInfo = null;
      isOfflineMode = _isRepoOffline;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    coreInfo = null;
    interiorSlides = const [];
    await load();
  }

  Future<void> retry() => reload();
}
