import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'app_tr.dart';
import 'app_en.dart';

class AppLocalizations {
  final bool isTurkish;

  const AppLocalizations({required this.isTurkish});

  static AppLocalizations of(BuildContext context) {
    bool isTr = true;
    try {
      isTr = context.watch<LanguageProvider>().isTurkish;
    } catch (_) {
      try {
        isTr = context.read<LanguageProvider>().isTurkish;
      } catch (_) {
        isTr = true;
      }
    }
    return AppLocalizations(isTurkish: isTr);
  }

  String tr(String key) {
    if (isTurkish) return AppTr.strings[key] ?? key;
    return AppEn.strings[key] ?? key;
  }
}

extension LocalizationExtension on BuildContext {
  String tr(String key) => AppLocalizations.of(this).tr(key);
}

