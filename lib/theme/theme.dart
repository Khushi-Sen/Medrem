import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primarySwatch: Colors.brown,
  scaffoldBackgroundColor: const Color(0xFFF8F3EF),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFD7CCC8),
    foregroundColor: Colors.brown,
  ),
  useMaterial3: true,
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.black12,
    foregroundColor: Colors.white,
  ),
  useMaterial3: true,
);
