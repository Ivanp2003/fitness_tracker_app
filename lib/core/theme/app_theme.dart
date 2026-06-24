import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier(ThemeMode.light);

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF0A8BFF),
    onPrimary: Colors.white,
    secondary: Color(0xFF12D6C8),
    onSecondary: Colors.white,
    surface: Color(0xFFF8FAFC),
    onSurface: Color(0xFF040B1A),
    error: Colors.red,
    onError: Colors.white,
  ),
  scaffoldBackgroundColor: const Color(0xFFF8FAFC),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0B1E3A),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF0A8BFF),
    onPrimary: Colors.white,
    secondary: Color(0xFF12D6C8),
    onSecondary: Color(0xFF040B1A),
    surface: Color(0xFF0B1E3A),
    onSurface: Color(0xFFF8FAFC),
    error: Colors.red,
    onError: Colors.white,
  ),
  scaffoldBackgroundColor: const Color(0xFF040B1A),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0B1E3A),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  cardTheme: const CardThemeData(color: Color(0xFF0B1E3A)),
);
