import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const FlexScheme _scheme = FlexScheme.materialBaseline;

  static ThemeData light = FlexThemeData.light(
    scheme: _scheme,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 7,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      blendOnColors: false,
      useTextTheme: true,
      useM2StyleDividerInM3: false,
      alignedDropdown: true,
      useInputDecoratorThemeInDialogs: true,
      defaultRadius: 28.0,
      thinBorderWidth: 1.0,
      thickBorderWidth: 2.0,
      textButtonRadius: 20.0,
      filledButtonRadius: 20.0,
      elevatedButtonRadius: 20.0,
      outlinedButtonRadius: 20.0,
      inputDecoratorRadius: 20.0,
      cardRadius: 28.0,
      fabRadius: 20.0,
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
    blendLevel: 13,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 20,
      useTextTheme: true,
      useM2StyleDividerInM3: false,
      alignedDropdown: true,
      useInputDecoratorThemeInDialogs: true,
      defaultRadius: 28.0,
      thinBorderWidth: 1.0,
      thickBorderWidth: 2.0,
      textButtonRadius: 20.0,
      filledButtonRadius: 20.0,
      elevatedButtonRadius: 20.0,
      outlinedButtonRadius: 20.0,
      inputDecoratorRadius: 20.0,
      cardRadius: 28.0,
      fabRadius: 20.0,
      navigationBarIndicatorOpacity: 0.24,
      navigationBarLabelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
  ).copyWith(
    textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, letterSpacing: -1),
      headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
    ),
  );
}
