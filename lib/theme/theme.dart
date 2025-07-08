import 'package:flutter/material.dart';

// Light Theme based on your main.dart's ThemeData
final ThemeData appLightTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
  scaffoldBackgroundColor: const Color(0xFFF8F3EF),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFD7CCC8),
    iconTheme: IconThemeData(color: Colors.brown),
    titleTextStyle: TextStyle(
      color: Colors.brown,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.brown,
      foregroundColor: Colors.white,
    ),
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(fontSize: 14.0),
    bodySmall: TextStyle(fontSize: 12.0),
  ),
);

// Dark Theme based on your main.dart's ThemeData
final ThemeData appDarkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: Colors.brown[300]!,
    secondary: Colors.brown,
  ),
  scaffoldBackgroundColor: Colors.black,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.black12,
    titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.brown,
      foregroundColor: Colors.white,
    ),
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(fontSize: 14.0),
    bodySmall: TextStyle(fontSize: 12.0),
  ),
);