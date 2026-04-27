import 'package:flutter/material.dart';
// Importă fișierele individuale
import 'ro.dart';
import 'en.dart';
import 'hu.dart';
import 'uk.dart';
import 'sk.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ro'));
  }

  String get(String key) {
    final map = _translationsMap[locale.languageCode] ?? translationsRo;
    return map[key] ?? key; // falls back to the key itself if missing
  }

  static const Map<String, Map<String, String>> _translationsMap = {
    'ro': translationsRo,
    'en': translationsEn,
    'hu': translationsHu,
    'uk': translationsUk,
    'sk': translationsSk,
  };
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ro', 'en', 'hu', 'uk', 'sk'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_) => false;
}
