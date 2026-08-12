import 'package:flutter/material.dart';

class AppTheme {
  static const String spaceGroteskFont = 'SpaceGrotesk';
  static const String manropeFont = 'Manrope';

  static const Color ink = Color(0xFF14201D);
  static const Color mist = Color(0xFFF3F6F5);
  static const Color surfaceMuted = Color(0xFFEDF2F0);
  static const Color line = Color(0xFFDCE5E1);
  static const Color emerald = Color(0xFF0B8F6A);
  static const Color teal = Color(0xFF087D7B);
  static const Color amber = Color(0xFFE09A2D);
  static const Color blue = Color(0xFF3568D4);
  static const Color rose = Color(0xFFD94C5C);

  // Dark neon design tokens for the futuristic dashboard redesign.
  static const Color voidBlack = Color(0xFF05070C);
  static const Color nebula = Color(0xFF0D1220);
  static const Color nebulaAlt = Color(0xFF141B2E);
  static const Color glassBorder = Color(0x1FFFFFFF);
  static const Color glassBorderStrong = Color(0x3DFFFFFF);
  static const Color neonEmerald = Color(0xFF3CF2C0);
  static const Color neonViolet = Color(0xFF9B7BFF);
  static const Color neonCyan = Color(0xFF4FE0FF);
  static const Color neonAmber = Color(0xFFFFC15C);
  static const Color neonRose = Color(0xFFFF5C88);
  static const Color textOnDark = Color(0xFFF2F5FA);
  static const Color textMutedOnDark = Color(0xFF8A94AC);

  /// A cycle of the neon accents used to give list items (categories,
  /// people) a stable, distinct color by identity rather than everything
  /// sharing one flat tone - the same trick contact apps and pie charts
  /// use so a list is scannable by color, not just by reading every label.
  static const List<Color> identityPalette = [
    neonEmerald,
    neonViolet,
    neonAmber,
    neonCyan,
    neonRose,
    teal,
  ];

  /// Deterministic: the same label always maps to the same color, so a
  /// category or person keeps its color across app restarts and screens.
  static Color colorForLabel(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized.isEmpty) return identityPalette.first;
    final hash = normalized.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return identityPalette[hash % identityPalette.length];
  }

  static ThemeData light() {
    const scheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: emerald,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDDF5EC),
      onPrimaryContainer: Color(0xFF073E31),
      secondary: amber,
      onSecondary: ink,
      secondaryContainer: Color(0xFFFFEECF),
      onSecondaryContainer: Color(0xFF4C3100),
      tertiary: blue,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFE4EBFF),
      onTertiaryContainer: Color(0xFF15346F),
      error: rose,
      errorContainer: Color(0xFFFFE5E8),
      onErrorContainer: Color(0xFF671C26),
      surface: Colors.white,
      onSurface: ink,
      onSurfaceVariant: Color(0xFF61706B),
      outline: Color(0xFFB9C6C1),
      outlineVariant: line,
      shadow: Color(0x1A14201D),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: mist,
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme(ink),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        toolbarHeight: 64,
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: line)),
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: ink.withValues(alpha: 0.28),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: line),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
        highlightElevation: 7,
        backgroundColor: ink,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDDF5EC),
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected)
                ? emerald
                : const Color(0xFF71807A),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? ink
                : const Color(0xFF71807A),
            letterSpacing: 0,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF61706B),
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A19C), letterSpacing: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: emerald, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: rose),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: rose, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: ink,
        disabledColor: surfaceMuted,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        labelStyle: const TextStyle(
          color: ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(BorderSide(color: line)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Dark neon fintech theme: near-black canvas, glass surfaces, glowing
  /// emerald/violet/cyan accents. Currently scoped to the dashboard preview
  /// (applied locally via a `Theme` wrapper) ahead of a full app rollout.
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: neonEmerald,
      onPrimary: Color(0xFF04231A),
      primaryContainer: Color(0xFF123B30),
      onPrimaryContainer: neonEmerald,
      secondary: neonViolet,
      onSecondary: Color(0xFF1C1240),
      secondaryContainer: Color(0xFF241A4D),
      onSecondaryContainer: neonViolet,
      tertiary: neonCyan,
      onTertiary: Color(0xFF07303B),
      tertiaryContainer: Color(0xFF0F3A47),
      onTertiaryContainer: neonCyan,
      error: neonRose,
      errorContainer: Color(0xFF3B1424),
      onErrorContainer: neonRose,
      surface: nebula,
      onSurface: textOnDark,
      onSurfaceVariant: textMutedOnDark,
      outline: Color(0xFF3A4560),
      outlineVariant: glassBorder,
      shadow: Color(0xCC000000),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: voidBlack,
      splashFactory: InkSparkle.splashFactory,
      textTheme: _neonTextTheme(textOnDark),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        toolbarHeight: 64,
        backgroundColor: Colors.transparent,
        foregroundColor: textOnDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontFamily: spaceGroteskFont,
          color: textOnDark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: nebula,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: glassBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(color: glassBorder, thickness: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: 0.62),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: neonEmerald,
          foregroundColor: const Color(0xFF04231A),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: manropeFont,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textOnDark,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: glassBorderStrong),
          textStyle: const TextStyle(
            fontFamily: manropeFont,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: neonCyan,
          textStyle: const TextStyle(
            fontFamily: manropeFont,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textOnDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
        backgroundColor: neonEmerald,
        foregroundColor: Color(0xFF04231A),
        shape: StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: nebula,
        indicatorColor: neonEmerald.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? neonEmerald
                : textMutedOnDark,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontFamily: manropeFont,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? textOnDark
                : textMutedOnDark,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: nebulaAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: const TextStyle(
          fontFamily: manropeFont,
          color: textMutedOnDark,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          fontFamily: manropeFont,
          color: textMutedOnDark.withValues(alpha: 0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: neonEmerald, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: neonRose),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: neonRose, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: nebulaAlt,
        selectedColor: neonEmerald,
        disabledColor: nebula,
        side: const BorderSide(color: glassBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        labelStyle: const TextStyle(
          fontFamily: manropeFont,
          color: textOnDark,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: manropeFont,
          color: Color(0xFF04231A),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(BorderSide(color: glassBorder)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: manropeFont,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: nebulaAlt,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: glassBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: nebulaAlt,
        contentTextStyle: const TextStyle(
          fontFamily: manropeFont,
          color: textOnDark,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: glassBorder),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color color) {
    return TextTheme(
      displaySmall: TextStyle(
        color: color,
        fontSize: 34,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        color: color,
        fontSize: 26,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: color,
        fontSize: 21,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: color,
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleSmall: TextStyle(
        color: color,
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        color: color,
        fontSize: 16,
        height: 1.45,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        color: color,
        fontSize: 14,
        height: 1.45,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        color: color,
        fontSize: 12,
        height: 1.4,
        letterSpacing: 0,
      ),
      labelLarge: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      labelSmall: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }

  /// Same type scale as [_textTheme], with a technical display face for
  /// headlines/figures and a clean grotesk for body copy.
  static TextTheme _neonTextTheme(Color color) {
    final base = _textTheme(color);
    TextStyle display(TextStyle? style) => (style ?? const TextStyle())
        .copyWith(fontFamily: spaceGroteskFont, letterSpacing: -0.2);
    TextStyle body(TextStyle? style) =>
        (style ?? const TextStyle()).copyWith(fontFamily: manropeFont);

    return base.copyWith(
      displaySmall: display(base.displaySmall),
      headlineSmall: display(base.headlineSmall),
      titleLarge: display(base.titleLarge),
      titleMedium: display(base.titleMedium),
      titleSmall: body(base.titleSmall),
      bodyLarge: body(base.bodyLarge),
      bodyMedium: body(base.bodyMedium),
      bodySmall: body(base.bodySmall),
      labelLarge: body(base.labelLarge),
      labelMedium: body(base.labelMedium),
      labelSmall: body(base.labelSmall),
    );
  }
}
