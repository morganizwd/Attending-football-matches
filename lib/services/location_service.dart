import 'dart:math' show cos, sqrt, asin;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:attending_football_matches/core/constants.dart';

class LocationService extends ChangeNotifier {
  Position? _lastPosition;
  bool _permissionGranted = false;
  String? _error;

  Position? get lastPosition => _lastPosition;
  bool get permissionGranted => _permissionGranted;
  String? get error => _error;

  Future<bool> requestPermission() async {
    _error = null;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _error = 'Служба геолокации отключена';
      notifyListeners();
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _error = 'Доступ к геолокации запрещён в настройках';
      _permissionGranted = false;
      notifyListeners();
      return false;
    }
    _permissionGranted = permission == LocationPermission.whileInUse || permission == LocationPermission.always;
    notifyListeners();
    return _permissionGranted;
  }

  Future<Position?> getCurrentPosition() async {
    if (!_permissionGranted) {
      final ok = await requestPermission();
      if (!ok) return null;
    }
    try {
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
      _error = null;
      notifyListeners();
      return _lastPosition;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Расстояние между двумя точками в метрах (формула Haversine).
  static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a));
  }

  bool isNearStadium(double userLat, double userLon, double stadiumLat, double stadiumLon) {
    final d = distanceMeters(userLat, userLon, stadiumLat, stadiumLon);
    return d <= stadiumProximityMeters;
  }

  Future<bool> isUserNearStadium(double stadiumLat, double stadiumLon) async {
    final pos = await getCurrentPosition();
    if (pos == null) return false;
    return isNearStadium(pos.latitude, pos.longitude, stadiumLat, stadiumLon);
  }
}
