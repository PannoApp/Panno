import 'package:flutter/material.dart';

/// Глобальный контроллер атмосферы (дыхание света / ambient loop).
class AmbientPresetScope extends InheritedWidget {
  const AmbientPresetScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final AnimationController controller;

  static AnimationController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AmbientPresetScope>();
    assert(scope != null, 'AmbientPresetScope not found in widget tree');
    return scope!.controller;
  }

  static AnimationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AmbientPresetScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(AmbientPresetScope oldWidget) =>
      controller != oldWidget.controller;
}
