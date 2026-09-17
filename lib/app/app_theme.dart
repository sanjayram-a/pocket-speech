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
    this.feedback = const Duration(milliseconds: 140),
    this.control = const Duration(milliseconds: 200),
    this.transition = const Duration(milliseconds: 260),
    this.slow = const Duration(milliseconds: 380),
  });

  final Duration feedback;
  final Duration control;
  final Duration transition;
  final Duration slow;

  @override
  AppMotion copyWith({
    Duration? feedback,
    Duration? control,
    Duration? transition,
    Duration? slow,
  }) => AppMotion(
    feedback: feedback ?? this.feedback,
    control: control ?? this.control,
    transition: transition ?? this.transition,
    slow: slow ?? this.slow,
  );

  @override
  AppMotion lerp(AppMotion? other, double t) => this;
}

@immutable
class AppShapes extends ThemeExtension<AppShapes> {
  const AppShapes({this.cardRadius = 20, this.controlRadius = 16});

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
    onSurfaceVariant: Color(0xFF6B6A63),
    outline: Color(0xFF77766F),
    outlineVariant: Color(0xFFE8E7E1),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF30302D),
    onInverseSurface: Color(0xFFF2F1EC),
    inversePrimary: Color(0xFFFFB59F),
    surfaceTint: Color(0xFFF5663F),
    surfaceContainer: Color(0xFFF6F3EF),
    surfaceContainerHigh: Color(0xFFEEEAE6),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFF7A5A),
    onPrimary: Color(0xFF4A1508),
    primaryContainer: Color(0xFF632314),
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
    surface: Color(0xFF1E1E1C),
    onSurface: Color(0xFFF5F4F0),
    onSurfaceVariant: Color(0xFFB8B7B0),
    outline: Color(0xFF92918A),
    outlineVariant: Color(0xFF3C3B36),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE5E2DE),
    onInverseSurface: Color(0xFF30302D),
    inversePrimary: Color(0xFF9E4128),
    surfaceTint: Color(0xFFFF825E),
    surfaceContainer: Color(0xFF262623),
    surfaceContainerHigh: Color(0xFF2F2F2D),
  );

  static ThemeData light() => _build(_lightScheme, const Color(0xFFF9F7F4));

  static ThemeData dark() => _build(_darkScheme, const Color(0xFF11110F));

  static ThemeData _build(ColorScheme scheme, Color scaffoldBackground) {
    const cardRadius = BorderRadius.all(Radius.circular(20));
    const controlRadius = BorderRadius.all(Radius.circular(16));
    const chipRadius = BorderRadius.all(Radius.circular(12));
    final baseTextTheme = Typography.material2021().black;
    final textTheme = baseTextTheme
        .copyWith(
          displaySmall: baseTextTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
            height: 1.05,
            fontSize: 32,
          ),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            height: 1.15,
          ),
          headlineSmall: baseTextTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: baseTextTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          labelLarge: baseTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          labelMedium: baseTextTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(height: 1.55),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(height: 1.5),
          bodySmall: baseTextTheme.bodySmall?.copyWith(height: 1.45),
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
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        shadowColor: scheme.shadow.withValues(alpha: 0.08),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant, width: 1.2),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1.1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            );
          }
          return textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimaryContainer, size: 24);
          }
          return IconThemeData(color: scheme.onSurfaceVariant, size: 22);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.9),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: controlRadius),
        elevation: 6,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: chipRadius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        dragHandleSize: const Size(40, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
    );
  }
}
