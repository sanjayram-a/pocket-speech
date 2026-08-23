import 'dart:math' as math;

import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Pocket Speech',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(size * 0.32),
          ),
          child: CustomPaint(
            painter: WaveformPainter(color: scheme.onPrimary, strokeWidth: 2.4),
          ),
        ),
      ),
    );
  }
}

class Waveform extends StatelessWidget {
  const Waveform({super.key, this.height = 84, this.semanticLabel});

  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? 'Audio waveform',
      image: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: CustomPaint(
              painter: WaveformPainter(
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  const WaveformPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  static const _levels = <double>[
    0.18,
    0.42,
    0.72,
    0.34,
    0.9,
    0.52,
    0.26,
    0.66,
    1,
    0.46,
    0.76,
    0.3,
    0.58,
    0.84,
    0.38,
    0.2,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final step = size.width / _levels.length;
    final center = size.height / 2;
    for (var i = 0; i < _levels.length; i++) {
      final amplitude = math.max(strokeWidth, center * _levels[i]);
      final x = step * (i + 0.5);
      canvas.drawLine(
        Offset(x, center - amplitude),
        Offset(x, center + amplitude),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}
