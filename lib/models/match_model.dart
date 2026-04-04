import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attending_football_matches/models/match_source.dart';
import 'package:attending_football_matches/models/stadium.dart';

enum VenueResolveStatus {
  unknown,
  resolved,
  resolvedNoCoords,
  stadiumNotFound,
  geocodeFailed,
}

class MatchModel {
  final String id;
  final MatchSource source;
  final String homeTeam;
  final String awayTeam;
  final String? homeTeamLogo;
  final String? awayTeamLogo;
  final String stadiumId;
  final Stadium? stadium;
  final DateTime startTime;
  final String? league;

  /// ID лиги из ответа API-Football (`league.id`), для фильтров и дедупликации.
  final int? apiFootballLeagueId;

  /// Код соревнования из football-data.org (`competition.code`), напр. `RFPL`.
  final String? footballDataCompetitionCode;

  final String? round;
  final String? description;
  final bool isActive;

  /// Короткий статус из внешнего API (например FT, NS, LIVE).
  final String? apiStatusShort;

  /// Данные арены из API (если нет привязки к Firestore-стадиону).
  final String? venueName;
  final String? venueCity;
  final double? venueLat;
  final double? venueLng;
  final String? venueImageUrl;
  final VenueResolveStatus venueResolveStatus;

  const MatchModel({
    required this.id,
    this.source = MatchSource.firestore,
    required this.homeTeam,
    required this.awayTeam,
    this.homeTeamLogo,
    this.awayTeamLogo,
    required this.stadiumId,
    this.stadium,
    required this.startTime,
    this.league,
    this.apiFootballLeagueId,
    this.footballDataCompetitionCode,
    this.round,
    this.description,
    this.isActive = true,
    this.apiStatusShort,
    this.venueName,
    this.venueCity,
    this.venueLat,
    this.venueLng,
    this.venueImageUrl,
    this.venueResolveStatus = VenueResolveStatus.unknown,
  });

  /// Стадион для геолокации: сначала Firestore, затем координаты из API.
  Stadium? get effectiveStadium {
    if (stadium != null) return stadium;
    if (venueLat != null && venueLng != null) {
      return Stadium.synthetic(
        id: 'venue_$id',
        name: venueName ?? 'Стадион',
        city: venueCity,
        latitude: venueLat!,
        longitude: venueLng!,
        imageUrl: venueImageUrl,
      );
    }
    return null;
  }

  String? get effectiveVenueImageUrl => stadium?.imageUrl ?? venueImageUrl;

  /// Отображаемое имя арены (для карточек без полного Stadium).
  String? get venueDisplayLine {
    if (stadium != null) return stadium!.name;
    if (venueName != null && venueName!.isNotEmpty) {
      if (venueCity != null && venueCity!.isNotEmpty) {
        return '$venueName · $venueCity';
      }
      return venueName;
    }
    return null;
  }

  String? get venueStatusLabel {
    switch (venueResolveStatus) {
      case VenueResolveStatus.unknown:
        return 'Данные стадиона загружаются';
      case VenueResolveStatus.resolved:
        if (effectiveVenueImageUrl == null || effectiveVenueImageUrl!.isEmpty) {
          return 'Фото стадиона не найдено';
        }
        return null;
      case VenueResolveStatus.resolvedNoCoords:
        if (effectiveVenueImageUrl != null && effectiveVenueImageUrl!.isNotEmpty) {
          return 'Координаты стадиона не найдены';
        }
        return 'Фото стадиона не найдено';
      case VenueResolveStatus.stadiumNotFound:
        return 'Стадион не найден';
      case VenueResolveStatus.geocodeFailed:
        return 'Геокод неуспешен';
    }
  }

  factory MatchModel.fromFirestore(DocumentSnapshot doc, {Stadium? stadium}) {
    final map = doc.data()! as Map<String, dynamic>;
    final Timestamp? ts = map['startTime'] as Timestamp?;
    return MatchModel(
      id: doc.id,
      source: MatchSource.firestore,
      homeTeam: map['homeTeam'] as String? ?? '',
      awayTeam: map['awayTeam'] as String? ?? '',
      homeTeamLogo: map['homeTeamLogo'] as String?,
      awayTeamLogo: map['awayTeamLogo'] as String?,
      stadiumId: map['stadiumId'] as String? ?? '',
      stadium: stadium,
      startTime: ts?.toDate() ?? DateTime.now(),
      league: map['league'] as String?,
      apiFootballLeagueId: null,
      footballDataCompetitionCode: null,
      round: map['round'] as String?,
      description: map['description'] as String?,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'homeTeamLogo': homeTeamLogo,
        'awayTeamLogo': awayTeamLogo,
        'stadiumId': stadiumId,
        'startTime': Timestamp.fromDate(startTime),
        'league': league,
        'round': round,
        'description': description,
        'isActive': isActive,
      };

  MatchModel copyWith({
    String? id,
    MatchSource? source,
    String? homeTeam,
    String? awayTeam,
    String? homeTeamLogo,
    String? awayTeamLogo,
    String? stadiumId,
    Stadium? stadium,
    DateTime? startTime,
    String? league,
    int? apiFootballLeagueId,
    String? footballDataCompetitionCode,
    String? round,
    String? description,
    bool? isActive,
    String? apiStatusShort,
    String? venueName,
    String? venueCity,
    double? venueLat,
    double? venueLng,
    String? venueImageUrl,
    VenueResolveStatus? venueResolveStatus,
    bool clearStadium = false,
  }) {
    return MatchModel(
      id: id ?? this.id,
      source: source ?? this.source,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      homeTeamLogo: homeTeamLogo ?? this.homeTeamLogo,
      awayTeamLogo: awayTeamLogo ?? this.awayTeamLogo,
      stadiumId: stadiumId ?? this.stadiumId,
      stadium: clearStadium ? null : (stadium ?? this.stadium),
      startTime: startTime ?? this.startTime,
      league: league ?? this.league,
      apiFootballLeagueId: apiFootballLeagueId ?? this.apiFootballLeagueId,
      footballDataCompetitionCode: footballDataCompetitionCode ?? this.footballDataCompetitionCode,
      round: round ?? this.round,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      apiStatusShort: apiStatusShort ?? this.apiStatusShort,
      venueName: venueName ?? this.venueName,
      venueCity: venueCity ?? this.venueCity,
      venueLat: venueLat ?? this.venueLat,
      venueLng: venueLng ?? this.venueLng,
      venueImageUrl: venueImageUrl ?? this.venueImageUrl,
      venueResolveStatus: venueResolveStatus ?? this.venueResolveStatus,
    );
  }

  String get title => '$homeTeam — $awayTeam';

  /// Сериализация для локального кэша матчей из внешних API (не Firestore).
  Map<String, dynamic> toJsonCache() {
    return {
      'id': id,
      'source': source.name,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'homeTeamLogo': homeTeamLogo,
      'awayTeamLogo': awayTeamLogo,
      'stadiumId': stadiumId,
      'stadium': stadium?.toJsonCache(),
      'startTime': startTime.toIso8601String(),
      'league': league,
      'apiFootballLeagueId': apiFootballLeagueId,
      'footballDataCompetitionCode': footballDataCompetitionCode,
      'round': round,
      'description': description,
      'isActive': isActive,
      'apiStatusShort': apiStatusShort,
      'venueName': venueName,
      'venueCity': venueCity,
      'venueLat': venueLat,
      'venueLng': venueLng,
      'venueImageUrl': venueImageUrl,
      'venueResolveStatus': venueResolveStatus.name,
    };
  }

  factory MatchModel.fromJsonCache(Map<String, dynamic> json) {
    final src = MatchSource.values.firstWhere(
      (e) => e.name == json['source'],
      orElse: () => MatchSource.apiFootball,
    );
    final vs = VenueResolveStatus.values.firstWhere(
      (e) => e.name == json['venueResolveStatus'],
      orElse: () => VenueResolveStatus.unknown,
    );
    Stadium? st;
    final sm = json['stadium'];
    if (sm is Map<String, dynamic>) {
      st = Stadium.fromJsonCache(sm);
    }
    final start = DateTime.tryParse(json['startTime'] as String? ?? '') ?? DateTime.now();
    return MatchModel(
      id: json['id'] as String? ?? '',
      source: src,
      homeTeam: json['homeTeam'] as String? ?? '',
      awayTeam: json['awayTeam'] as String? ?? '',
      homeTeamLogo: json['homeTeamLogo'] as String?,
      awayTeamLogo: json['awayTeamLogo'] as String?,
      stadiumId: json['stadiumId'] as String? ?? '',
      stadium: st,
      startTime: start,
      league: json['league'] as String?,
      apiFootballLeagueId: (json['apiFootballLeagueId'] as num?)?.toInt(),
      footballDataCompetitionCode: json['footballDataCompetitionCode'] as String?,
      round: json['round'] as String?,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      apiStatusShort: json['apiStatusShort'] as String?,
      venueName: json['venueName'] as String?,
      venueCity: json['venueCity'] as String?,
      venueLat: (json['venueLat'] as num?)?.toDouble(),
      venueLng: (json['venueLng'] as num?)?.toDouble(),
      venueImageUrl: json['venueImageUrl'] as String?,
      venueResolveStatus: vs,
    );
  }
}
