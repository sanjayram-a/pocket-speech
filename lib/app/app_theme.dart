import 'package:flutter/material.dart';

@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.xxl = 32,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  @override
  AppSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
  }) => AppSpacing(
    xs: xs ?? this.xs,
    sm: sm ?? this.sm,
    md: md ?? this.md,
    lg: lg ?? this.lg,
    xl: xl ?? this.xl,
    xxl: xxl ?? this.xxl,
  );

  @override
  AppSpacing lerp(AppSpacing? other, double t) => this;
}

@immutable
class AppMotion extends ThemeExtension<AppMotion> {
  const AppMotion({
    this.feedback = const Duration(milliseconds: 120),
    this.control = const Duration(milliseconds: 180),
    this.transition = const Duration(milliseconds: 240),
  });

  final Duration feedback;
  final Duration control;
  final Duration transition;

  @override
  AppMotion copyWith({
    Duration? feedback,
    Duration? control,
    Duration? transition,
  }) => AppMotion(
    feedback: feedback ?? this.feedback,
    control: control ?? this.control,
    transition: transition ?? this.transition,
  );

  @override
  AppMotion lerp(AppMotion? other, double t) => this;
}

@immutable
class AppShapes extends ThemeExtension<AppShapes> {
  const AppShapes({this.cardRadius = 22, this.controlRadius = 16});

  /// Radius used for the curved top corners of the bottom navigation bar.
  static const double navBarTopRadius = 28;

  BorderRadius get navBar =>
      const BorderRadius.vertical(top: Radius.circular(navBarTopRadius));

  final double cardRadius;
  final double controlRadius;

  BorderRadius get card => BorderRadius.circular(cardRadius);

  BorderRadius get control => BorderRadius.circular(controlRadius);

  @override
  AppShapes copyWith({double? cardRadius, double? controlRadius}) => AppShapes(
    cardRadius: cardRadius ?? this.cardRadius,
    controlRadius: controlRadius ?? this.controlRadius,
  );

  @override
  AppShapes lerp(AppShapes? other, double t) => this;
}

extension AppThemeTokens on BuildContext {
  AppSpacing get spacing => Theme.of(this).extension<AppSpacing>()!;

  AppMotion get motion => Theme.of(this).extension<AppMotion>()!;

  AppShapes get shapes => Theme.of(this).extension<AppShapes>()!;
}

abstract final class AppTheme {
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFF5663F),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFE9DF),
    onPrimaryContainer: Color(0xFF4C170A),
    secondary: Color(0xFF363630),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE7E6DF),
    onSecondaryContainer: Color(0xFF20201D),
    tertiary: Color(0xFF785B42),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFDCC2),
    onTertiaryContainer: Color(0xFF2C1606),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF191917),
    onSurfaceVariant: Color(0xFF686862),
    outline: Color(0xFF77766F),
    outlineVariant: Color(0xFFDDDCD6),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF30302D),
    onInverseSurface: Color(0xFFF2F1EC),
    inversePrimary: Color(0xFFFFB59F),
    surfaceTint: Color(0xFFF5663F),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFF825E),
    onPrimary: Color(0xFF271008),
    primaryContainer: Color(0xFF522417),
    onPrimaryContainer: Color(0xFFFFDAD0),
    secondary: Color(0xFFD0CFC8),
    onSecondary: Color(0xFF292925),
    secondaryContainer: Color(0xFF3A3A35),
    onSecondaryContainer: Color(0xFFECEBE4),
    tertiary: Color(0xFFE9BE9C),
    onTertiary: Color(0xFF432B17),
    tertiaryContainer: Color(0xFF5C412B),
    onTertiaryContainer: Color(0xFFFFDCC2),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF1B1B19),
    onSurface: Color(0xFFF7F6F1),
    onSurfaceVariant: Color(0xFFB8B7B0),
    outline: Color(0xFF92918A),
    outlineVariant: Color(0xFF3C3B36),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE5E2DE),
    onInverseSurface: Color(0xFF30302D),
    inversePrimary: Color(0xFF9E4128),
    surfaceTint: Color(0xFFFF825E),
  );

  static ThemeData light() => _build(_lightScheme, const Color(0xFFF4F4F1));

  static ThemeData dark() => _build(_darkScheme, const Color(0xFF10100F));

  static ThemeData _build(ColorScheme scheme, Color scaffoldBackground) {
    const cardRadius = BorderRadius.all(Radius.circular(22));
    const controlRadius = BorderRadius.all(Radius.circular(16));
    final baseTextTheme = Typography.material2021().black;
    final textTheme = baseTextTheme
        .copyWith(
          displaySmall: baseTextTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
          ),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          labelLarge: baseTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      extensions: const [AppSpacing(), AppMotion(), AppShapes()],
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: cardRadius),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.all(18),
        border: const OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: controlRadius),
      ),
    );
  }
}
