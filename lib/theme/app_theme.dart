import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A single named color palette. AppColors below always mirrors whichever
/// AppPalette is currently active, so existing `AppColors.primary`-style
/// call sites across the app don't need to change to support theming.
class AppPalette {
  final String id;
  final String label;
  final Brightness brightness;

  final Color primary;
  final Color primaryDark;
  final Color primaryLight;

  final Color secondary;
  final Color secondaryLight;

  final Color accent;

  final Color background;
  final Color surface;
  final Color cardBackground;

  final Color textPrimary;
  final Color textSecondary;
  final Color textOnPrimary;

  final Color periodColor;
  final Color periodColorLight;
  final Color fertileColor;
  final Color fertileColorLight;
  final Color ovulationColor;
  final Color predictedColor;
  final Color todayBorder;

  final Color healthy;
  final Color attention;
  final Color concern;

  final Color divider;
  final Color shadow;

  const AppPalette({
    required this.id,
    required this.label,
    required this.brightness,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.secondary,
    required this.secondaryLight,
    required this.accent,
    required this.background,
    required this.surface,
    required this.cardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnPrimary,
    required this.periodColor,
    required this.periodColorLight,
    required this.fertileColor,
    required this.fertileColorLight,
    required this.ovulationColor,
    required this.predictedColor,
    required this.todayBorder,
    required this.healthy,
    required this.attention,
    required this.concern,
    required this.divider,
    required this.shadow,
  });
}

/// All themes the user can pick from in Profile > Appearance.
class ThemeCatalog {
  ThemeCatalog._();

  static const rose = AppPalette(
    id: 'rose',
    label: 'Rose (default)',
    brightness: Brightness.light,
    primary: Color(0xFFE8A0BF),
    primaryDark: Color(0xFFD37A9E),
    primaryLight: Color(0xFFF8DDE6),
    secondary: Color(0xFFB9A6DD),
    secondaryLight: Color(0xFFE6DEF7),
    accent: Color(0xFFFFC2D1),
    background: Color(0xFFFFF8FA),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFF1F5),
    textPrimary: Color(0xFF3D2C3A),
    textSecondary: Color(0xFF8A7686),
    textOnPrimary: Color(0xFFFFFFFF),
    periodColor: Color(0xFFE8607F),
    periodColorLight: Color(0xFFF7C6D2),
    fertileColor: Color(0xFF8FD3C7),
    fertileColorLight: Color(0xFFD3F0EA),
    ovulationColor: Color(0xFF6FB7B7),
    predictedColor: Color(0xFFD8B4E2),
    todayBorder: Color(0xFFB9446B),
    healthy: Color(0xFF7CB88F),
    attention: Color(0xFFE3A857),
    concern: Color(0xFFDB6B6B),
    divider: Color(0xFFF0DDE3),
    shadow: Color(0x1AB9446B),
  );

  static const lavender = AppPalette(
    id: 'lavender',
    label: 'Lavender',
    brightness: Brightness.light,
    primary: Color(0xFFA994D6),
    primaryDark: Color(0xFF8870BD),
    primaryLight: Color(0xFFE6DEF7),
    secondary: Color(0xFFE8A0BF),
    secondaryLight: Color(0xFFF8DDE6),
    accent: Color(0xFFC9B6F5),
    background: Color(0xFFFAF8FF),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFF3EFFC),
    textPrimary: Color(0xFF332C42),
    textSecondary: Color(0xFF7E7691),
    textOnPrimary: Color(0xFFFFFFFF),
    periodColor: Color(0xFFE8607F),
    periodColorLight: Color(0xFFF7C6D2),
    fertileColor: Color(0xFF8FD3C7),
    fertileColorLight: Color(0xFFD3F0EA),
    ovulationColor: Color(0xFF6FB7B7),
    predictedColor: Color(0xFFB9A6DD),
    todayBorder: Color(0xFF8870BD),
    healthy: Color(0xFF7CB88F),
    attention: Color(0xFFE3A857),
    concern: Color(0xFFDB6B6B),
    divider: Color(0xFFE6DEF0),
    shadow: Color(0x1A8870BD),
  );

  static const ocean = AppPalette(
    id: 'ocean',
    label: 'Ocean',
    brightness: Brightness.light,
    primary: Color(0xFF6FB7B7),
    primaryDark: Color(0xFF4F9999),
    primaryLight: Color(0xFFD3F0EA),
    secondary: Color(0xFF8FA9D3),
    secondaryLight: Color(0xFFDDE6F7),
    accent: Color(0xFF9AD6D0),
    background: Color(0xFFF6FBFB),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFEDF7F6),
    textPrimary: Color(0xFF263A3D),
    textSecondary: Color(0xFF6F8A8C),
    textOnPrimary: Color(0xFFFFFFFF),
    periodColor: Color(0xFFE8607F),
    periodColorLight: Color(0xFFF7C6D2),
    fertileColor: Color(0xFF4F9999),
    fertileColorLight: Color(0xFFD3F0EA),
    ovulationColor: Color(0xFF3D8A8A),
    predictedColor: Color(0xFF8FA9D3),
    todayBorder: Color(0xFF4F9999),
    healthy: Color(0xFF7CB88F),
    attention: Color(0xFFE3A857),
    concern: Color(0xFFDB6B6B),
    divider: Color(0xFFDDEDEB),
    shadow: Color(0x1A4F9999),
  );

  static const dark = AppPalette(
    id: 'dark',
    label: 'Dark',
    brightness: Brightness.dark,
    primary: Color(0xFFE8A0BF),
    primaryDark: Color(0xFFD37A9E),
    primaryLight: Color(0xFF4A3540),
    secondary: Color(0xFFB9A6DD),
    secondaryLight: Color(0xFF3A3550),
    accent: Color(0xFFFFC2D1),
    background: Color(0xFF1C1620),
    surface: Color(0xFF262029),
    cardBackground: Color(0xFF2E2731),
    textPrimary: Color(0xFFF2E8EE),
    textSecondary: Color(0xFFAFA0AA),
    textOnPrimary: Color(0xFF1C1620),
    periodColor: Color(0xFFE8607F),
    periodColorLight: Color(0xFF4A2A33),
    fertileColor: Color(0xFF8FD3C7),
    fertileColorLight: Color(0xFF253A38),
    ovulationColor: Color(0xFF6FB7B7),
    predictedColor: Color(0xFFD8B4E2),
    todayBorder: Color(0xFFE8A0BF),
    healthy: Color(0xFF7CB88F),
    attention: Color(0xFFE3A857),
    concern: Color(0xFFE88080),
    divider: Color(0xFF3A333D),
    shadow: Color(0x40000000),
  );

  static const List<AppPalette> all = [rose, lavender, ocean, dark];

  static AppPalette byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => rose);
}

/// Mutable color "constants" the rest of the app reads. These mirror
/// ThemeController's currently active palette. They start as the rose
/// theme so the app has sane colors before settings are loaded, and are
/// overwritten in place (not reassigned) by ThemeController.apply() —
/// existing `AppColors.primary` call sites across the app keep working
/// unchanged and just pick up new values after a rebuild.
class AppColors {
  AppColors._();

  static Color primary = ThemeCatalog.rose.primary;
  static Color primaryDark = ThemeCatalog.rose.primaryDark;
  static Color primaryLight = ThemeCatalog.rose.primaryLight;

  static Color secondary = ThemeCatalog.rose.secondary;
  static Color secondaryLight = ThemeCatalog.rose.secondaryLight;

  static Color accent = ThemeCatalog.rose.accent;

  static Color background = ThemeCatalog.rose.background;
  static Color surface = ThemeCatalog.rose.surface;
  static Color cardBackground = ThemeCatalog.rose.cardBackground;

  static Color textPrimary = ThemeCatalog.rose.textPrimary;
  static Color textSecondary = ThemeCatalog.rose.textSecondary;
  static Color textOnPrimary = ThemeCatalog.rose.textOnPrimary;

  static Color periodColor = ThemeCatalog.rose.periodColor;
  static Color periodColorLight = ThemeCatalog.rose.periodColorLight;
  static Color fertileColor = ThemeCatalog.rose.fertileColor;
  static Color fertileColorLight = ThemeCatalog.rose.fertileColorLight;
  static Color ovulationColor = ThemeCatalog.rose.ovulationColor;
  static Color predictedColor = ThemeCatalog.rose.predictedColor;
  static Color todayBorder = ThemeCatalog.rose.todayBorder;

  static Color healthy = ThemeCatalog.rose.healthy;
  static Color attention = ThemeCatalog.rose.attention;
  static Color concern = ThemeCatalog.rose.concern;

  static Color divider = ThemeCatalog.rose.divider;
  static Color shadow = ThemeCatalog.rose.shadow;

  static void _applyPalette(AppPalette p) {
    primary = p.primary;
    primaryDark = p.primaryDark;
    primaryLight = p.primaryLight;
    secondary = p.secondary;
    secondaryLight = p.secondaryLight;
    accent = p.accent;
    background = p.background;
    surface = p.surface;
    cardBackground = p.cardBackground;
    textPrimary = p.textPrimary;
    textSecondary = p.textSecondary;
    textOnPrimary = p.textOnPrimary;
    periodColor = p.periodColor;
    periodColorLight = p.periodColorLight;
    fertileColor = p.fertileColor;
    fertileColorLight = p.fertileColorLight;
    ovulationColor = p.ovulationColor;
    predictedColor = p.predictedColor;
    todayBorder = p.todayBorder;
    healthy = p.healthy;
    attention = p.attention;
    concern = p.concern;
    divider = p.divider;
    shadow = p.shadow;
  }
}

/// Holds the currently selected theme id and notifies listeners (the app
/// root) when it changes, so the whole tree rebuilds with new colors.
/// Persistence to UserSettings.themeName is the caller's responsibility
/// (see ProfileScreen's theme picker) — this class only handles the
/// in-memory/live side of switching.
class ThemeController extends ChangeNotifier {
  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  AppPalette _active = ThemeCatalog.rose;
  AppPalette get active => _active;

  /// Call once during app startup with the saved theme id (or 'rose' if
  /// none saved yet) before runApp, so the first frame already has the
  /// right colors.
  void initialize(String savedThemeId) {
    _active = ThemeCatalog.byId(savedThemeId);
    AppColors._applyPalette(_active);
  }

  /// Switch theme at runtime. Does not persist — call CycleRepository to
  /// save the choice as well if it should survive app restarts.
  void select(String themeId) {
    final palette = ThemeCatalog.byId(themeId);
    if (palette.id == _active.id) return;
    _active = palette;
    AppColors._applyPalette(palette);
    notifyListeners();
  }
}

class AppTheme {
  AppTheme._();

  /// Builds a ThemeData from whichever palette is currently active.
  /// Call this fresh (don't cache the result) any time the active theme
  /// may have changed, e.g. from a listener on ThemeController.
  static ThemeData themeFor(AppPalette p) {
    final base = p.brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      brightness: p.brightness,
      scaffoldBackgroundColor: p.background,
      primaryColor: p.primary,
      colorScheme: base.colorScheme.copyWith(
        brightness: p.brightness,
        primary: p.primary,
        secondary: p.secondary,
        surface: p.surface,
        error: p.concern,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: p.textPrimary),
        titleTextStyle: GoogleFonts.poppins(
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.textOnPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
      ),
      useMaterial3: true,
    );
  }

  /// Kept for compatibility with any existing reference to AppTheme.lightTheme
  /// — now just builds from whichever palette is active.
  static ThemeData get lightTheme => themeFor(ThemeController.instance.active);
}
