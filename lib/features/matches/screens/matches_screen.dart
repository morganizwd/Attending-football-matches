import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attending_football_matches/services/auth_service.dart';
import 'package:attending_football_matches/services/attendance_service.dart';
import 'package:attending_football_matches/models/match_model.dart';
import 'package:attending_football_matches/features/matches/screens/match_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:attending_football_matches/core/constants.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _queryController = TextEditingController();
  String _query = '';
  String? _leagueFilter;
  List<MatchModel> _matches = [];
  bool _loading = true;
  bool _onlyMy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final attendance = context.read<AttendanceService>();
    final auth = context.read<AuthService>();
    final userId = auth.currentUser?.uid;

    var list = await attendance.getMatches(
      query: _query.isEmpty ? null : _query,
      league: _leagueFilter,
    );

    if (_onlyMy && userId != null) {
      final intents = await attendance.getMyIntents(userId);
      final Set<String> myMatchIds = intents.map((e) => e.matchId).toSet();
      list = list.where((m) => myMatchIds.contains(m.id)).toList();
    }
    if (mounted) {
      setState(() {
        _matches = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Матчи'),
          actions: [
            if (_leagueFilter != null)
              IconButton(
                icon: const Icon(Icons.filter_alt_off),
                tooltip: 'Сбросить фильтры',
                onPressed: () {
                  setState(() => _leagueFilter = null);
                  _load();
                },
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Предстоящие'),
              Tab(text: 'Прошедшие'),
            ],
          ),
        ),
        body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withOpacity(0.08),
              colorScheme.secondary.withOpacity(0.05),
              colorScheme.surface,
            ],
          ),
        ),
          child: Column(
            children: [
              Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          decoration: InputDecoration(
                            hintText: 'Поиск по командам, лиге...',
                            prefixIcon: const Icon(Icons.search),
                          ),
                          onSubmitted: (v) {
                            setState(() => _query = v);
                            _load();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _load,
                        icon: const Icon(Icons.search),
                      ),
                    ],
                  ),
                ),
              ),
              ),
              Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Только мои матчи'),
                    selected: _onlyMy,
                    onSelected: (v) {
                      setState(() => _onlyMy = v);
                      _load();
                    },
                  ),
                  Chip(
                    avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text('Найдено: ${_matches.length}'),
                  ),
                ],
              ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        children: [
                          _buildMatchesList(context, upcoming: true),
                          _buildMatchesList(context, upcoming: false),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchesList(BuildContext context, {required bool upcoming}) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final matches = _matches;
    final filtered = matches.where((m) {
      final start = m.startTime;
      final end = start.add(const Duration(minutes: minutesAfterMatchStart));
      final isOngoing = !now.isBefore(start) && !now.isAfter(end);
      final isFuture = now.isBefore(start);
      final isPastDone = now.isAfter(end);
      if (upcoming) {
        return isFuture || isOngoing;
      } else {
        return isPastDone;
      }
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (filtered.isEmpty) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_soccer, size: 72, color: colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  upcoming ? 'Нет предстоящих матчей' : 'Пока нет завершённых матчей',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (upcoming) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Добавьте матчи в разделе Админ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final m = filtered[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _MatchCard(match: m, onTap: () => _openDetail(m)),
        );
      },
    );
  }

  void _openDetail(MatchModel m) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MatchDetailScreen(match: m),
      ),
    ).then((_) => _load());
  }
}

class _MatchCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onTap;

  const _MatchCard({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final start = match.startTime;
    final end = start.add(const Duration(minutes: minutesAfterMatchStart));
    final isToday = start.year == now.year && start.month == now.month && start.day == now.day;
    final isOngoing = !now.isBefore(start) && !now.isAfter(end);

    final stadiumImage = match.stadium?.imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Material(
        color: colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 188,
            decoration: BoxDecoration(color: colorScheme.surface),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (stadiumImage != null && stadiumImage.isNotEmpty)
                  Image.network(
                    stadiumImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => Container(
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withOpacity(0.25),
                          colorScheme.tertiary.withOpacity(0.2),
                        ],
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.22),
                        Colors.black.withOpacity(0.72),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: -60,
                  top: -70,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.secondary.withOpacity(0.12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (match.league != null && match.league!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white.withOpacity(0.22)),
                              ),
                              child: Text(
                                match.league!,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOngoing
                                  ? colorScheme.tertiary
                                  : isToday
                                      ? colorScheme.secondary
                                      : Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isOngoing
                                  ? 'Идёт сейчас'
                                  : isToday
                                      ? 'Сегодня'
                                      : DateFormat('dd MMM').format(match.startTime),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isOngoing || isToday ? colorScheme.onSecondary : Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _TeamBadge(
                            name: match.homeTeam,
                            logoUrl: match.homeTeamLogo,
                            alignment: Alignment.centerLeft,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'VS',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(width: 10),
                          _TeamBadge(
                            name: match.awayTeam,
                            logoUrl: match.awayTeamLogo,
                            alignment: Alignment.centerRight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.white.withOpacity(0.9)),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('EEE • HH:mm', 'ru').format(match.startTime),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                          ),
                          if (match.stadium != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.stadium_outlined, size: 16, color: Colors.white.withOpacity(0.9)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                match.stadium!.name,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final Alignment alignment;

  const _TeamBadge({
    required this.name,
    required this.logoUrl,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: alignment == Alignment.centerRight ? TextAlign.end : TextAlign.start,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
    );

    final avatar = CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white.withOpacity(0.18),
      backgroundImage: (logoUrl != null && logoUrl!.isNotEmpty) ? NetworkImage(logoUrl!) : null,
      child: (logoUrl == null || logoUrl!.isEmpty)
          ? Text(
              name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
            )
          : null,
    );

    return Expanded(
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (alignment == Alignment.centerLeft) avatar,
          if (alignment == Alignment.centerLeft) const SizedBox(width: 8),
          Flexible(child: text),
          if (alignment == Alignment.centerRight) const SizedBox(width: 8),
          if (alignment == Alignment.centerRight) avatar,
        ],
      ),
    );
  }
}
