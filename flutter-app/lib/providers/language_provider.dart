import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';
  
  Locale _currentLocale = const Locale('fr'); // Default to French
  
  Locale get currentLocale => _currentLocale;
  
  String get currentLanguageCode => _currentLocale.languageCode;
  
  LanguageProvider() {
    _loadSavedLanguage();
  }
  
  // Supported languages
  static const Map<String, Map<String, String>> supportedLanguages = {
    'en': {
      'name': 'English',
      'flag': '🇬🇧',
      'nativeName': 'English',
    },
    'fr': {
      'name': 'Français',
      'flag': '🇫🇷',
      'nativeName': 'Français',
    },
    'ar': {
      'name': 'العربية',
      'flag': '🇸🇦',
      'nativeName': 'العربية',
    },
  };
  
  List<Locale> get supportedLocales {
    return supportedLanguages.keys.map((code) => Locale(code)).toList();
  }
  
  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_languageKey);
    
    if (savedLanguage != null && supportedLanguages.containsKey(savedLanguage)) {
      _currentLocale = Locale(savedLanguage);
      notifyListeners();
    }
  }
  
  Future<void> changeLanguage(String languageCode) async {
    if (!supportedLanguages.containsKey(languageCode)) return;
    if (_currentLocale.languageCode == languageCode) return;
    
    _currentLocale = Locale(languageCode);
    
    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    
    notifyListeners();
  }
  
  String getLanguageName(String languageCode) {
    return supportedLanguages[languageCode]?['name'] ?? 'Unknown';
  }
  
  String getLanguageFlag(String languageCode) {
    return supportedLanguages[languageCode]?['flag'] ?? '🌐';
  }
  
  bool get isRTL {
    return _currentLocale.languageCode == 'ar';
  }
  
  TextDirection get textDirection {
    return isRTL ? TextDirection.rtl : TextDirection.ltr;
  }
}
