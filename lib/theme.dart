import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0A0A0D);
  static const surface = Color(0xFF15131B);
  static const surfaceHi = Color(0xFF1F1B29);
  static const purple = Color(0xFF9D6BFF);
  static const purpleDeep = Color(0xFF6C3BEA);
  static const text = Color(0xFFF2EEFA);
  static const muted = Color(0xFF8E87A0);

  /// Note background presets.
  static const noteColors = <int>[
    0xFFFFF59D, 0xFFFFCC80, 0xFFFFAB91, 0xFFF48FB1, 0xFFCE93D8,
    0xFFB39DDB, 0xFF90CAF9, 0xFF80DEEA, 0xFFA5D6A7, 0xFFE6EE9C,
    0xFFFFFFFF, 0xFF9D6BFF, 0xFF4527A0, 0xFF263238, 0xFF1E1B26, 0xFF000000,
  ];

  /// Text colour presets.
  static const textColors = <int>[
    0xFF1A1A1A, 0xFFFFFFFF, 0xFF4527A0, 0xFFD1C4FF,
    0xFFB71C1C, 0xFF0D47A1, 0xFF1B5E20, 0xFF5D4037,
  ];

  /// Picks a readable default text colour for a background.
  static int contrastFor(int bg) =>
      Color(bg).computeLuminance() > 0.45 ? 0xFF1A1A1A : 0xFFFFFFFF;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.purple,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.purple,
    secondary: AppColors.purple,
    surface: AppColors.surface,
    onSurface: AppColors.text,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.text,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHi,
      contentTextStyle: const TextStyle(color: AppColors.text),
      actionTextColor: AppColors.purple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.purple,
      foregroundColor: Colors.white,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.purple,
      thumbColor: AppColors.purple,
      inactiveTrackColor: AppColors.surfaceHi,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}
