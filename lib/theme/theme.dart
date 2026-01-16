import 'package:attendzone_new/theme/custom_theme/elevated_button_theme.dart';
import 'package:flutter/material.dart';

// Orange Theme Colors
const Color kOrange = Color(0xFFFF9800);
const Color kOrangeDark = Color(0xFFF57C00);
const Color kOrangeLight = Color(0xFFFFE0B2);
const Color kLightBackground = Color(0xFFF9F9F9);
const Color kDarkBackground = Color(0xFF0F0F0F);
const Color kDarkSurface = Color(0xFF1A1A1A);

ThemeData lightMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kOrange,
    brightness: Brightness.light,
    primary: kOrange,
    secondary: kOrangeDark,
    background: kLightBackground,
    surface: Colors.white,
    onSurface: Colors.black,
    onSecondary: Colors.white,
  ),
  elevatedButtonTheme: EElevatedButtonTheme.lightElevatedButtonTheme,
);

ThemeData darkMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kOrange,
    brightness: Brightness.dark,
    primary: kOrange,
    secondary: kOrangeLight,
    background: kDarkBackground,
    surface: kDarkSurface,
    onSurface: Colors.white,
    onSecondary: Colors.black,
  ),
  elevatedButtonTheme: EElevatedButtonTheme.darkElevatedButtonTheme,
);
