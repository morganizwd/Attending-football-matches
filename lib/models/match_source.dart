/// Источник данных о матче.
enum MatchSource {
  /// Локальные матчи из Firestore (админ-панель).
  firestore,

  /// API-Football (api-sports.io / RapidAPI).
  apiFootball,

  /// football-data.org v4.
  footballDataOrg,
}
