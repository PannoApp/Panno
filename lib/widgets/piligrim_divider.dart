// Стандартные разделители PILIGRIM — тонкие линии и drag-handle для шторок.
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Тонкая горизонтальная линия-разделитель.
class PiligrimDivider extends StatelessWidget {
  const PiligrimDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.thickness = 0.5,
    this.color,
  });

  final double indent;
  final double endIndent;
  final double thickness;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: Container(
        width: double.infinity,
        height: thickness,
        color: color ?? PiligrimColors.sky.withValues(alpha: 0.06),
      ),
    );
  }
}

/// Drag-handle для BottomSheet (36×3, скруглённый, по центру).
class PiligrimDragHandle extends StatelessWidget {
  const PiligrimDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 3,
        decoration: BoxDecoration(
          color: PiligrimColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
