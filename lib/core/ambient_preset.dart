import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppAmbientPreset { calm, ember, mystic }

extension AppAmbientPresetX on AppAmbientPreset {
  String get storageValue => name;

  String get title {
    switch (this) {
      case AppAmbientPreset.calm:
        return 'Calm';
      case AppAmbientPreset.ember:
        return 'Ember';
      case AppAmbientPreset.mystic:
        return 'Mystic';
    }
  }

  String get subtitle {
    switch (this) {
      case AppAmbientPreset.calm:
        return 'Мягкий и спокойный';
      case AppAmbientPreset.ember:
        return 'Тёплый огненный';
      case AppAmbientPreset.mystic:
        return 'Глубокий мистический';
    }
  }

  static AppAmbientPreset fromStorage(String? raw) {
    return AppAmbientPreset.values.firstWhere(
      (p) => p.name == raw,
      orElse: () => AppAmbientPreset.ember,
    );
  }
}

class AmbientPresetController extends ValueNotifier<AppAmbientPreset> {
  AmbientPresetController() : super(AppAmbientPreset.ember);

  static const _prefsKey = 'ambient_preset';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = AppAmbientPresetX.fromStorage(prefs.getString(_prefsKey));
  }

  Future<void> setPreset(AppAmbientPreset preset) async {
    if (value == preset) return;
    value = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, preset.storageValue);
  }
}

class AmbientPresetScope extends InheritedNotifier<AmbientPresetController> {
  const AmbientPresetScope({
    super.key,
    required AmbientPresetController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppAmbientPreset of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AmbientPresetScope>();
    return scope?.notifier?.value ?? AppAmbientPreset.ember;
  }

  static AmbientPresetController controllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AmbientPresetScope>();
    if (scope?.notifier == null) {
      throw StateError('AmbientPresetScope not found in widget tree');
    }
    return scope!.notifier!;
  }
}
