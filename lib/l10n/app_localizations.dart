import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'app_tr.dart';
import 'app_en.dart';

class AppLocalizations {
  final bool isTurkish;

  const AppLocalizations({required this.isTurkish});

  static AppLocalizations of(BuildContext context) {
    final isTurkish = context.watch<LanguageProvider>().isTurkish;
    return AppLocalizations(isTurkish: isTurkish);
  }

  String tr(String key) {
    if (isTurkish) return AppTr.strings[key] ?? key;
    return AppEn.strings[key] ?? key;
  }
}
