import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from the Puff Design Book v1.0. Tokens are the source of
/// truth — when in doubt, ship the quieter option.
abstract final class PuffPalette {
  static const cloud = Color(0xFFF4FAF6);
  static const mint = Color(0xFFD7F5E9);
  static const mintBright = Color(0xFF5DCAA5);
  static const mintSoft = Color(0xFF9FE1CB);
  static const teal = Color(0xFF1D9E75);
  static const deepTeal = Color(0xFF0F6E56);
  static const pine = Color(0xFF0A4536);
  static const cream = Color(0xFFFFF1D6);
  static const coral = Color(0xFFE0603A);
  static const coralSoft = Color(0xFFF0997B);
  static const coralDeep = Color(0xFF993C1D);
  static const ink = Color(0xFF1E2A38);
  static const inkDeep = Color(0xFF141D28);
  static const inkRaised = Color(0xFF26354A);
}

/// Corner radii: cards 28, controls 18, chips fully round. Nothing sharp.
abstract final class PuffRadius {
  static const lg = 28.0;
  static const md = 18.0;
  static const pill = 999.0;
}

/// Semantic tokens that ThemeData/ColorScheme has no slot for. Depth in Puff
/// comes from [pillow] (the hard offset under buttons) and surface steps —
/// never drop shadows.
class PuffColors extends ThemeExtension<PuffColors> {
  const PuffColors({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.textPrimary,
    required this.textSecondary,
    required this.action,
    required this.pillow,
    required this.onAction,
    required this.pro,
    required this.onPro,
    required this.proPillow,
    required this.streakBg,
    required this.streakFg,
    required this.hairline,
    required this.chipSelectedBg,
    required this.chipSelectedBorder,
    required this.barIdle,
    required this.barHot,
  });

  final Color canvas;
  final Color surface;
  final Color raised;
  final Color textPrimary;
  final Color textSecondary;
  final Color action;
  final Color pillow;
  final Color onAction;
  final Color pro;
  final Color onPro;
  final Color proPillow;
  final Color streakBg;
  final Color streakFg;
  final Color hairline;
  final Color chipSelectedBg;
  final Color chipSelectedBorder;
  final Color barIdle;
  final Color barHot;

  static const light = PuffColors(
    canvas: PuffPalette.cloud,
    surface: Colors.white,
    raised: PuffPalette.mint,
    textPrimary: PuffPalette.ink,
    textSecondary: Color(0xFF7B8B98),
    action: PuffPalette.teal,
    pillow: PuffPalette.deepTeal,
    onAction: Colors.white,
    pro: PuffPalette.coral,
    onPro: Colors.white,
    proPillow: PuffPalette.coralDeep,
    streakBg: PuffPalette.cream,
    streakFg: PuffPalette.coralDeep,
    hairline: Color(0xFFDCEAE0),
    chipSelectedBg: PuffPalette.mint,
    chipSelectedBorder: PuffPalette.teal,
    barIdle: PuffPalette.mintSoft,
    barHot: PuffPalette.teal,
  );

  // On the dark canvas, sea mint replaces teal everywhere — teal fails
  // contrast on ink and is not used in dark mode.
  static const dark = PuffColors(
    canvas: PuffPalette.inkDeep,
    surface: Color(0xFF1B2635),
    raised: PuffPalette.inkRaised,
    textPrimary: Color(0xFFEAF4EE),
    textSecondary: Color(0xFF8DA0B3),
    action: PuffPalette.mintBright,
    pillow: Color(0xFF2E8065),
    onAction: PuffPalette.inkDeep,
    pro: PuffPalette.coralSoft,
    onPro: Color(0xFF3A1608),
    proPillow: PuffPalette.coralDeep,
    streakBg: Color(0xFF3A2A22),
    streakFg: PuffPalette.coralSoft,
    hairline: Color(0xFF2C3D52),
    chipSelectedBg: Color(0xFF0F3A2D),
    chipSelectedBorder: PuffPalette.mintBright,
    barIdle: Color(0xFF2E4A3F),
    barHot: PuffPalette.mintBright,
  );

  @override
  PuffColors copyWith() => this;

  @override
  PuffColors lerp(ThemeExtension<PuffColors>? other, double t) =>
      t < 0.5 ? this : (other as PuffColors? ?? this);
}

extension PuffThemeContext on BuildContext {
  PuffColors get puff => Theme.of(this).extension<PuffColors>()!;
}

/// Baloo 2 speaks with the brand's voice (headings, buttons, every stat
/// numeral); Nunito is for everything the user reads. Never italic Baloo,
/// never long paragraphs in Baloo.
TextTheme _textTheme(PuffColors c) {
  final baloo = GoogleFonts.baloo2TextTheme();
  final nunito = GoogleFonts.nunitoTextTheme();
  return TextTheme(
    // counter 72
    displayLarge: baloo.displayLarge!.copyWith(
      fontSize: 72,
      fontWeight: FontWeight.w700,
      color: c.action,
      height: 1.0,
    ),
    // display 34
    displayMedium: baloo.displayMedium!.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: c.textPrimary,
    ),
    // headline 26
    headlineMedium: baloo.headlineMedium!.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w600,
      color: c.textPrimary,
    ),
    // title 20
    titleLarge: baloo.titleLarge!.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: c.textPrimary,
    ),
    titleMedium: baloo.titleMedium!.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: c.textPrimary,
    ),
    // body 16 / secondary 14
    bodyLarge: nunito.bodyLarge!.copyWith(fontSize: 16, color: c.textPrimary),
    bodyMedium: nunito.bodyMedium!.copyWith(fontSize: 14, color: c.textPrimary),
    bodySmall: nunito.bodySmall!.copyWith(fontSize: 12.5, color: c.textSecondary),
    // caption 12.5, uppercase applied at usage sites
    labelSmall: nunito.labelSmall!.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
      color: c.textSecondary,
    ),
    labelLarge: baloo.labelLarge!.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
  );
}

ThemeData puffTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? PuffColors.light : PuffColors.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.action,
    onPrimary: c.onAction,
    primaryContainer: c.raised,
    onPrimaryContainer: c.textPrimary,
    secondary: c.pro,
    onSecondary: c.onPro,
    surface: c.surface,
    onSurface: c.textPrimary,
    surfaceContainerHighest: c.raised,
    error: c.pro,
    onError: c.onPro,
    outline: c.hairline,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.canvas,
    textTheme: _textTheme(c),
    splashFactory: NoSplash.splashFactory,
    dividerColor: c.hairline,
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0, // no drop shadows anywhere
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PuffRadius.lg),
        side: BorderSide(color: c.hairline),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PuffRadius.lg),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PuffRadius.lg)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.textPrimary,
      contentTextStyle: GoogleFonts.nunito(
        fontSize: 14,
        color: c.canvas,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PuffRadius.md),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PuffRadius.md),
        borderSide: BorderSide(color: c.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PuffRadius.md),
        borderSide: BorderSide(color: c.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PuffRadius.md),
        borderSide: BorderSide(color: c.action, width: 2),
      ),
    ),
    extensions: [c],
  );
}
