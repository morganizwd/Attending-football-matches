import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TextScaleService extends ChangeNotifier {
  static const _key = 'textScaleFactor';

  double _factor = 1.0;
  bool _loaded = false;

  double get factor => _factor;
  bool get loaded => _loaded;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _factor = prefs.getDouble(_key) ?? 1.0;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setFactor(double factor) async {
    final f = factor.clamp(0.85, 1.25).toDouble();
    if (_factor == f && _loaded) return;
    _factor = f;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, _factor);
  }
}

