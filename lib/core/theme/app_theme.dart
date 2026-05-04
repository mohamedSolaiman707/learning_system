import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ألوان احترافية (Enterprise Palette)
  static const Color primaryColor = Color(0xFF0061FF);
  static const Color secondaryColor = Color(0xFF00C6FF);
  static const Color accentColor = Color(0xFFFF9800);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFE11D48);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: surfaceColor,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        displayLarge: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: textPrimary),
        displayMedium: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: textPrimary),
        titleLarge: GoogleFonts.cairo(fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.cairo(color: textPrimary),
        bodyMedium: GoogleFonts.cairo(color: textSecondary),
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIconColor: textSecondary,
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
      ),
    );
  }
}
