import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attending_football_matches/models/stadium.dart';

class MatchModel {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String? homeTeamLogo;
  final String? awayTeamLogo;
  final String stadiumId;
  final Stadium? stadium;
  final DateTime startTime;
  final String? league;
  final String? round;
  final String? description;
  final bool isActive;

  const MatchModel({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    this.homeTeamLogo,
    this.awayTeamLogo,
    required this.stadiumId,
    this.stadium,
    required this.startTime,
    this.league,
    this.round,
    this.description,
    this.isActive = true,
  });

  factory MatchModel.fromFirestore(DocumentSnapshot doc, {Stadium? stadium}) {
    final map = doc.data()! as Map<String, dynamic>;
    Timestamp? ts = map['startTime'] as Timestamp?;
    return MatchModel(
      id: doc.id,
      homeTeam: map['homeTeam'] as String? ?? '',
      awayTeam: map['awayTeam'] as String? ?? '',
      homeTeamLogo: map['homeTeamLogo'] as String?,
      awayTeamLogo: map['awayTeamLogo'] as String?,
      stadiumId: map['stadiumId'] as String? ?? '',
      stadium: stadium,
      startTime: ts?.toDate() ?? DateTime.now(),
      league: map['league'] as String?,
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

  String get title => '$homeTeam — $awayTeam';
}
