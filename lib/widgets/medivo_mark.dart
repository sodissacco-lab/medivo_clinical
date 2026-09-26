import 'package:flutter/material.dart';

/// The Medivo Clinical mark, drawn in code so it needs no image files:
/// a white cross on a teal tile with an amber spark.
/// Proportions follow the 256 x 256 master in the brand system.
class MedivoMark extends StatelessWidget {
  const MedivoMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size / 256;
    Widget bar() => DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10 * s),
          ),
        );

    return Semantics(
      label: 'Medivo Clinical',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF0E5C57),
                  borderRadius: BorderRadius.circular(56 * s),
                ),
              ),
            ),
            Positioned(left: 104 * s, top: 60 * s, width: 48 * s, height: 136 * s, child: bar()),
            Positioned(left: 60 * s, top: 104 * s, width: 136 * s, height: 48 * s, child: bar()),
            Positioned(
              left: 166 * s,
              top: 50 * s,
              width: 40 * s,
              height: 40 * s,
              child: const DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFE8A33D), shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
