import 'package:flutter/material.dart';

/// Хранит выбранный режим темы (системная / светлая / тёмная).
class ThemeService extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}

