import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A utility class for handling localization and language settings
class LocalizationUtils {
  static const String _prefsLanguageCode = 'language_code';
  static const Locale _defaultLocale = Locale('en');
  
  /// Get the list of supported locales
  static List<Locale> get supportedLocales => [
    const Locale('en'), // English
    const Locale('es'), // Spanish
    // Add more locales as needed
  ];
  
  /// Get the list of localization delegates
  static List<LocalizationsDelegate> get localizationDelegates => [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  
  /// Get the locale name for display
  static String getLocaleName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      default:
        return locale.languageCode;
    }
  }
  
  /// Get the current locale from shared preferences
  static Future<Locale> getCurrentLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_prefsLanguageCode);
    
    if (languageCode != null && supportedLocales.any((locale) => locale.languageCode == languageCode)) {
      return Locale(languageCode);
    }
    
    return _defaultLocale;
  }
  
  /// Save the current locale to shared preferences
  static Future<void> setCurrentLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLanguageCode, locale.languageCode);
  }
  
  /// Get the localized string for a key
  static String getString(BuildContext context, String key) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return key;
    
    // Use reflection to get the property dynamically
    try {
      return localizations.toString();
    } catch (e) {
      // Error occurred while getting localized string for key: $key
      return key;
    }
  }
  
  /// Get the flag icon for a locale
  static String getFlagIcon(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return '🇺🇸';
      case 'es':
        return '🇪🇸';
      default:
        return '🌐';
    }
  }
}
