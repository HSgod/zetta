import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Wybieramy schemat "Dell" lub "Mallard" dla bardziej ekspresyjnego wyglądu (lub zostajemy przy deepBlue)
  static const FlexScheme _scheme = FlexScheme.materialBaseline;

  static ThemeData light = FlexThemeData.light(
    scheme: _scheme,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 12,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 15,
      blendOnColors: false,
      useTextTheme: true,
      useM2StyleDividerInM3: false,
      alignedDropdown: true,
      useInputDecoratorThemeInDialogs: true,
      // Ekspresyjne zaokrąglenia
      defaultRadius: 24.0,
      elevatedButtonRadius: 20.0,
      cardRadius: 24.0,
      inputDecoratorRadius: 20.0,
      fabRadius: 16.0,
      // Paski nawigacji
      navigationBarIndicatorOpacity: 0.24,
      navigationBarLabelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
  );

  static ThemeData dark = FlexThemeData.dark(
    scheme: _scheme,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 18,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 25,
      useTextTheme: true,
      useM2StyleDividerInM3: false,
      alignedDropdown: true,
      useInputDecoratorThemeInDialogs: true,
      // Ekspresyjne zaokrąglenia
      defaultRadius: 24.0,
      elevatedButtonRadius: 20.0,
      cardRadius: 24.0,
      inputDecoratorRadius: 20.0,
      fabRadius: 16.0,
      // Paski nawigacji
      navigationBarIndicatorOpacity: 0.24,
      navigationBarLabelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
  ).copyWith(
    // Dodatkowe dopieszczenie typografii dla trybu ciemnego
    textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, letterSpacing: -1),
      headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
    ),
  );
}