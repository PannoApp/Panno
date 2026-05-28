import 'package:flutter/material.dart';
import 'piligrim_tap.dart';

/// Unified back/close navigation button for pushed and fullscreen screens.
///
/// Use [Icons.chevron_left] for back navigation (push stack).
/// Use [Icons.close] for modal / fullscreen dismiss.
class PiligrimNavButton extends StatelessWidget {
  const PiligrimNavButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 0.5,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
