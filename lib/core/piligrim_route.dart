import 'package:flutter/material.dart';

/// PILIGRIM custom page transition — fade + subtle upward lift.
///
/// Replaces MaterialPageRoute on all detail/pushed screens so the app
/// feels authored rather than stock Flutter. Enter: 280ms easeOutCubic.
/// Exit reverse: 220ms easeIn.
class PiligrimPageRoute<T> extends PageRouteBuilder<T> {
  PiligrimPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          pageBuilder: (context, _, __) => builder(context),
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeIn,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
