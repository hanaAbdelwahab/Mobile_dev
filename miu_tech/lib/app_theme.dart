import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ================= App Colors =================
// All color definitions for the app
class AppColors {
  // Brand Colors
  static const Color primaryRed = Color(0xFFE63946);
  static const Color primaryRedDark = Color(0xFFDC2F41);
  
  // Admin Dashboard Colors
  static const Color adminBlue = Color(0xFF2196F3);
  static const Color adminBlueDark = Color(0xFF1976D2);
  static const Color adminGreen = Color(0xFF4CAF50);
  static const Color adminGreenDark = Color(0xFF388E3C);
  static const Color adminPurple = Color(0xFF9C27B0);
  static const Color adminPurpleDark = Color(0xFF7B1FA2);
  static const Color adminOrange = Color(0xFFFF9800);
  static const Color adminOrangeDark = Color(0xFFF57C00);
  
  // Badge & Notification Colors
  static const Color badgeOrange = Color(0xFFFF9800);
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Light Theme Colors
  static const Color lightBackground = Colors.white;
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceVariant = Color(0xFFF5F5F5);
  static const Color lightCardBackground = Colors.white;
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightTextTertiary = Color(0xFF9E9E9E);
  static const Color lightIconSecondary = Color(0xFF9E9E9E);
  static const Color lightShadow = Color(0x0D000000); // Black with 5% opacity
  
  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);
  static const Color darkCardBackground = Color(0xFF1E1E1E);
  static const Color darkDivider = Color(0xFF373737);
  static const Color darkTextPrimary = Color(0xFFE1E1E1);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextTertiary = Color(0xFF8E8E8E);
  static const Color darkIconSecondary = Color(0xFF8E8E8E);
  static const Color darkShadow = Color(0x33000000); // Black with 20% opacity
}

// ================= BuildContext Extensions =================
// Easy access to theme colors throughout the app
extension ThemeExtension on BuildContext {
  // Check if dark mode is active
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  
  // Background Colors
  Color get scaffoldBackgroundColor => isDarkMode 
      ? AppColors.darkBackground 
      : AppColors.lightBackground;
  
  Color get cardBackgroundColor => isDarkMode 
      ? AppColors.darkCardBackground 
      : AppColors.lightCardBackground;
  
  Color get surfaceVariant => isDarkMode 
      ? AppColors.darkSurfaceVariant 
      : AppColors.lightSurfaceVariant;
  
  // Text Colors
  Color get textPrimary => isDarkMode 
      ? AppColors.darkTextPrimary 
      : AppColors.lightTextPrimary;
  
  Color get textSecondary => isDarkMode 
      ? AppColors.darkTextSecondary 
      : AppColors.lightTextSecondary;
  
  Color get textTertiary => isDarkMode 
      ? AppColors.darkTextTertiary 
      : AppColors.lightTextTertiary;
  
  // Icon Colors
  Color get iconSecondary => isDarkMode 
      ? AppColors.darkIconSecondary 
      : AppColors.lightIconSecondary;
  
  // Divider & Border Colors
  Color get dividerColor => isDarkMode 
      ? AppColors.darkDivider 
      : AppColors.lightDivider;
  
  // Shadow Color
  Color get shadowColor => isDarkMode 
      ? AppColors.darkShadow 
      : AppColors.lightShadow;
  
  // Status Colors
  Color get errorColor => AppColors.error;
  Color get successColor => AppColors.success;
  Color get warningColor => AppColors.warning;
  Color get infoColor => AppColors.info;
  
  // Admin Colors (adaptive)
  Color get adminBlue => isDarkMode 
      ? AppColors.adminBlueDark 
      : AppColors.adminBlue;
  
  Color get adminGreen => isDarkMode 
      ? AppColors.adminGreenDark 
      : AppColors.adminGreen;
  
  Color get adminPurple => isDarkMode 
      ? AppColors.adminPurpleDark 
      : AppColors.adminPurple;
  
  Color get adminOrange => isDarkMode 
      ? AppColors.adminOrangeDark 
      : AppColors.adminOrange;
}

// ================= App Theme Configuration =================
class AppTheme {
  // ================= Light Theme Data =================
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    // Primary colors
    primaryColor: AppColors.primaryRed,
    scaffoldBackgroundColor: AppColors.lightBackground,
    
    // Color scheme
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryRed,
      secondary: AppColors.primaryRedDark,
      surface: AppColors.lightSurface,
      surfaceContainerHighest: AppColors.lightSurfaceVariant,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightTextPrimary,
      onError: Colors.white,
    ),
    
    // Card theme
    cardTheme: CardThemeData(
      color: AppColors.lightCardBackground,
      elevation: 2,
      shadowColor: AppColors.lightShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    // AppBar theme
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.lightBackground,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    
    // Text theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: AppColors.lightTextPrimary),
      bodyMedium: TextStyle(color: AppColors.lightTextSecondary),
      bodySmall: TextStyle(color: AppColors.lightTextTertiary),
      labelLarge: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: AppColors.lightTextSecondary),
      labelSmall: TextStyle(color: AppColors.lightTextTertiary),
    ),
    
    // Icon theme
    iconTheme: const IconThemeData(
      color: AppColors.lightTextPrimary,
    ),
    
    // Divider theme
    dividerTheme: const DividerThemeData(
      color: AppColors.lightDivider,
      thickness: 1,
    ),
    
    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
      ),
    ),
    
    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryRed,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    
    // Bottom navigation bar theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightBackground,
      selectedItemColor: AppColors.primaryRed,
      unselectedItemColor: AppColors.lightTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    
    fontFamily: 'Roboto',
  );
  
  // ================= Dark Theme Data =================
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    // Primary colors
    primaryColor: AppColors.primaryRed,
    scaffoldBackgroundColor: AppColors.darkBackground,
    
    // Color scheme
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryRed,
      secondary: AppColors.primaryRedDark,
      surface: AppColors.darkSurface,
      surfaceContainerHighest: AppColors.darkSurfaceVariant,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
      onError: Colors.white,
    ),
    
    // Card theme
    cardTheme: CardThemeData(
      color: AppColors.darkCardBackground,
      elevation: 4,
      shadowColor: AppColors.darkShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    // AppBar theme
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.darkBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    
    // Text theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
      bodyMedium: TextStyle(color: AppColors.darkTextSecondary),
      bodySmall: TextStyle(color: AppColors.darkTextTertiary),
      labelLarge: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: AppColors.darkTextSecondary),
      labelSmall: TextStyle(color: AppColors.darkTextTertiary),
    ),
    
    // Icon theme
    iconTheme: const IconThemeData(
      color: AppColors.darkTextPrimary,
    ),
    
    // Divider theme
    dividerTheme: const DividerThemeData(
      color: AppColors.darkDivider,
      thickness: 1,
    ),
    
    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
      ),
    ),
    
    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryRed,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    
    // Bottom navigation bar theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.primaryRed,
      unselectedItemColor: AppColors.darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    
    fontFamily: 'Roboto',
  );
  
  // ================= Backward Compatibility Helper Methods =================
  // (Kept for any existing code using AppTheme.getAccentBlue style)
  
  static Color getAccentBlue(BuildContext context) {
    return context.isDarkMode ? AppColors.adminBlueDark : AppColors.adminBlue;
  }
  
  static Color getAccentGreen(BuildContext context) {
    return context.isDarkMode ? AppColors.adminGreenDark : AppColors.adminGreen;
  }
  
  static Color getAccentPurple(BuildContext context) {
    return context.isDarkMode ? AppColors.adminPurpleDark : AppColors.adminPurple;
  }
  
  static Color getAccentOrange(BuildContext context) {
    return context.isDarkMode ? AppColors.adminOrangeDark : AppColors.adminOrange;
  }
  
  static Color getSurfaceVariant(BuildContext context) {
    return context.surfaceVariant;
  }
  
  static Color getTextPrimary(BuildContext context) {
    return context.textPrimary;
  }
  
  static Color getTextSecondary(BuildContext context) {
    return context.textSecondary;
  }
  
  static Color getTextTertiary(BuildContext context) {
    return context.textTertiary;
  }
}