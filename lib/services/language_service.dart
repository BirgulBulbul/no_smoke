import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_service.dart';

class LanguageService {
  static const String _languageCodeKey = 'selected_language_code';

  static const Map<String, Locale> supportedLanguages = {
    'tr': Locale('tr'),
    'en': Locale('en'),
    'de': Locale('de'),
    'ar': Locale('ar'),
    'fr': Locale('fr'),
    'es': Locale('es'),
  };

  static Future<String> loadSelectedLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_languageCodeKey) ?? 'tr';
    return supportedLanguages.containsKey(code) ? code : 'tr';
  }

  static Future<bool> hasSavedLanguageSelection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_languageCodeKey);
  }

  static Future<Locale> loadSelectedLocale() async {
    final code = await loadSelectedLanguageCode();
    return supportedLanguages[code] ?? const Locale('tr');
  }

  static Future<void> saveSelectedLanguageCode(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    final code = supportedLanguages.containsKey(languageCode) ? languageCode : 'tr';
    await prefs.setString(_languageCodeKey, code);
    await StorageService().saveLanguageSelectionHistory(code);
  }
}