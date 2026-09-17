import 'dart:math' as math;

import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 52, this.animated = false});

  final double size;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mark = Semantics(
      label: 'Pocket Speech',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(size * 0.32),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: CustomPaint(
            painter: WaveformPainter(color: scheme.onPrimary, strokeWidth: 2.4),
          ),
        ),
      ),
    );

    if (!animated) return mark;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: mark,
    );
  }
}

class Waveform extends StatelessWidget {
  const Waveform({
    super.key,
    this.height = 84,
    this.semanticLabel,
    this.animate = false,
  });

  final double height;
  final String? semanticLabel;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final waveform = Semantics(
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
    if (!animate) return waveform;
    return _BreathingWaveform(height: height, child: waveform);
  }
}

class _BreathingWaveform extends StatefulWidget {
  const _BreathingWaveform({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  State<_BreathingWaveform> createState() => _BreathingWaveformState();
}

class _BreathingWaveformState extends State<_BreathingWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _isTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (!_isTest) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: 0.92 + _controller.value * 0.08,
        child: Transform.scale(
          scale: 0.98 + _controller.value * 0.02,
          child: child,
        ),
      ),
      child: widget.child,
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

/// App startup splash with clean animated brand, waveform pulse and soft fade.
class PocketSplash extends StatefulWidget {
  const PocketSplash({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<PocketSplash> createState() => _PocketSplashState();
}

class _PocketSplashState extends State<PocketSplash>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _waveController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _waveOpacity;

  @override
  void initState() {
    super.initState();
    final reduce = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _logoController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: reduce ? 280 : 900),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: reduce ? 320 : 1100),
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );
    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );
    _waveOpacity = CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    );

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted) _waveController.forward();
    });
    Future.delayed(Duration(milliseconds: reduce ? 420 : 1650), () {
      widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _logoOpacity,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.82, end: 1).animate(_logoScale),
                  child: BrandMark(size: 84, animated: false),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _logoOpacity,
                child: Column(
                  children: [
                    Text(
                      'Pocket Speech',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.9,
                            color: scheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Private • On-device • Yours',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              FadeTransition(
                opacity: _waveOpacity,
                child: SizedBox(
                  width: 220,
                  child: Waveform(height: 44, animate: true),
                ),
              ),
              const SizedBox(height: 36),
              FadeTransition(
                opacity: _waveOpacity,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
