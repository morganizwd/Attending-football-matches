/// Радиус (в метрах), в котором пользователь считается «у стадиона».
const double stadiumProximityMeters = 500.0;

/// За сколько минут до начала матча разрешать проверку геолокации.
const int minutesBeforeMatchStart = 60;

/// Сколько минут после начала матча ещё считаем посещение (опоздание).
const int minutesAfterMatchStart = 180;

/// Интервал проверки геолокации в день матча (секунды).
const int locationCheckIntervalSeconds = 120;

/// Коллекции Firestore.
abstract class FirestoreCollections {
  static const String users = 'users';
  static const String matches = 'matches';
  static const String stadiums = 'stadiums';
  static const String intents = 'intents';
  static const String attendances = 'attendances';
  static const String achievements = 'achievements';
}
