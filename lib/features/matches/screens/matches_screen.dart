import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attending_football_matches/services/auth_service.dart';
import 'package:attending_football_matches/services/attendance_service.dart';
import 'package:attending_football_matches/models/match_model.dart';
import 'package:attending_football_matches/models/match_source.dart';
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
  static const int _pageSize = 20;
  String _query = '';
  String? _leagueFilter;
  MatchSource? _sourceFilter;
  MatchSort _sort = MatchSort.startTimeAsc;
  List<MatchModel> _upcomingMatches = [];
  List<MatchModel> _pastMatches = [];
  bool _hasMoreUpcoming = true;
  bool _hasMorePast = true;
  int _upcomingPage = 1;
  int _pastPage = 1;
  List<String> _leagueOptions = [];
  bool _loading = true;
  bool _onlyMy = false;
  bool _onlyRussia = false;
  int _loadRequestId = 0;
  bool _resolvingUnknown = false;

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

  Future<void> _load({bool resetPages = true}) async {
    final requestId = ++_loadRequestId;
    setState(() => _loading = true);

    if (resetPages) {
      _upcomingPage = 1;
      _pastPage = 1;
      _hasMoreUpcoming = true;
      _hasMorePast = true;
    }

    final attendance = context.read<AttendanceService>();
    final auth = context.read<AuthService>();
    final userId = auth.currentUser?.uid;
    Set<String> myMatchIds = {};
    if (_onlyMy && userId != null) {
      final intents = await attendance.getMyIntents(userId);
      myMatchIds = intents.map((e) => e.matchId).toSet();
    }

    final now = DateTime.now();
    final upcomingFrom = now.subtract(const Duration(hours: 3));
    final upcomingTo = now.add(const Duration(days: 45));
    final pastFrom = now.subtract(const Duration(days: 60));
    final pastTo = now.add(const Duration(hours: 3));

    final loaded = await Future.wait([
      attendance.getMatches(
        query: _query.isEmpty ? null : _query,
        league: _leagueFilter,
        source: _sourceFilter,
        sort: _sort,
        page: _upcomingPage,
        pageSize: _pageSize,
        from: upcomingFrom,
        to: upcomingTo,
        onlyRussia: _onlyRussia,
      ),
      attendance.getMatches(
        query: _query.isEmpty ? null : _query,
        league: _leagueFilter,
        source: _sourceFilter,
        sort: _sort,
        page: _pastPage,
        pageSize: _pageSize,
        from: pastFrom,
        to: pastTo,
        onlyRussia: _onlyRussia,
      ),
    ]);
    var upcoming = loaded[0];
    var past = loaded[1];

    if (_onlyMy && userId != null) {
      upcoming = upcoming.where((m) => myMatchIds.contains(m.id)).toList();
      past = past.where((m) => myMatchIds.contains(m.id)).toList();
    }

    final leagues = <String>{
      ..._leagueOptions,
      ...upcoming.map((m) => m.league).whereType<String>().where((v) => v.isNotEmpty),
      ...past.map((m) => m.league).whereType<String>().where((v) => v.isNotEmpty),
    }.toList()
      ..sort();

    if (mounted && requestId == _loadRequestId) {
      setState(() {
        _upcomingMatches = upcoming;
        _pastMatches = past;
        _hasMoreUpcoming = upcoming.length == _pageSize;
        _hasMorePast = past.length == _pageSize;
        _leagueOptions = leagues;
        _loading = false;
      });
      _resolveUnknownInBackground();
    }
  }

  Future<void> _loadMore({required bool upcoming}) async {
    if (_loading) return;
    if (upcoming && !_hasMoreUpcoming) return;
    if (!upcoming && !_hasMorePast) return;

    final attendance = context.read<AttendanceService>();
    final auth = context.read<AuthService>();
    final userId = auth.currentUser?.uid;
    Set<String> myMatchIds = {};
    if (_onlyMy && userId != null) {
      final intents = await attendance.getMyIntents(userId);
      myMatchIds = intents.map((e) => e.matchId).toSet();
    }

    final now = DateTime.now();
    final from = upcoming ? now.subtract(const Duration(hours: 3)) : now.subtract(const Duration(days: 60));
    final to = upcoming ? now.add(const Duration(days: 45)) : now.add(const Duration(hours: 3));
    final nextPage = upcoming ? (_upcomingPage + 1) : (_pastPage + 1);

    var next = await attendance.getMatches(
      query: _query.isEmpty ? null : _query,
      league: _leagueFilter,
      source: _sourceFilter,
      sort: _sort,
      page: nextPage,
      pageSize: _pageSize,
      from: from,
      to: to,
      onlyRussia: _onlyRussia,
    );
    if (_onlyMy && userId != null) {
      next = next.where((m) => myMatchIds.contains(m.id)).toList();
    }

    if (!mounted) return;
    setState(() {
      if (upcoming) {
        _upcomingPage = nextPage;
        _upcomingMatches = [..._upcomingMatches, ...next];
        _hasMoreUpcoming = next.length == _pageSize;
      } else {
        _pastPage = nextPage;
        _pastMatches = [..._pastMatches, ...next];
        _hasMorePast = next.length == _pageSize;
      }
    });
    _resolveUnknownInBackground();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showInitialLoader = _loading && _upcomingMatches.isEmpty && _pastMatches.isEmpty;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Матчи'),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Фильтры и сортировка',
              onPressed: _openFiltersSheet,
            ),
            if (_leagueFilter != null ||
                _sourceFilter != null ||
                _sort != MatchSort.startTimeAsc ||
                _onlyMy ||
                _onlyRussia)
              IconButton(
                icon: const Icon(Icons.filter_alt_off),
                tooltip: 'Сбросить фильтры',
                onPressed: () {
                  setState(() {
                    _leagueFilter = null;
                    _sourceFilter = null;
                    _sort = MatchSort.startTimeAsc;
                    _onlyMy = false;
                    _onlyRussia = false;
                  });
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
                  FilterChip(
                    label: const Text('Только Россия'),
                    selected: _onlyRussia,
                    onSelected: (v) {
                      setState(() {
                        _onlyRussia = v;
                        if (v) _leagueFilter = null;
                      });
                      _load();
                    },
                  ),
                  Chip(
                    avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text('Найдено: ${_upcomingMatches.length + _pastMatches.length}'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.tune, size: 18),
                    label: Text(_filtersSummaryLabel()),
                    onPressed: _openFiltersSheet,
                  ),
                ],
              ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _ApiMatchesBanner(matches: [..._upcomingMatches, ..._pastMatches]),
              ),
              Expanded(
                child: showInitialLoader
                    ? const Center(child: CircularProgressIndicator())
                    : Stack(
                        children: [
                          TabBarView(
                            children: [
                              _buildMatchesList(context, upcoming: true),
                              _buildMatchesList(context, upcoming: false),
                            ],
                          ),
                          if (_loading)
                            const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
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
    final filtered = upcoming ? _upcomingMatches : _pastMatches;

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
                    'Добавьте матчи в админке или подключите API (см. README).',
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      children: [
        ...filtered.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _MatchCard(match: m, onTap: () => _openDetail(m)),
          ),
        ),
        if (upcoming ? _hasMoreUpcoming : _hasMorePast)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Center(
              child: FilledButton.tonalIcon(
                onPressed: () => _loadMore(upcoming: upcoming),
                icon: const Icon(Icons.expand_more),
                label: const Text('Показать ещё'),
              ),
            ),
          ),
      ],
    );
  }

  void _openDetail(MatchModel m) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MatchDetailScreen(match: m),
      ),
    ).then((_) => _load());
  }

  Future<void> _resolveUnknownInBackground() async {
    if (_resolvingUnknown || !mounted) return;
    _resolvingUnknown = true;
    try {
      final attendance = context.read<AttendanceService>();
      final candidates = <MatchModel>[
        ..._upcomingMatches,
        ..._pastMatches,
      ]
          .where(
            (m) =>
                m.source != MatchSource.firestore &&
                m.venueResolveStatus == VenueResolveStatus.unknown,
          )
          .take(8)
          .toList();
      if (candidates.isEmpty) return;

      for (final m in candidates) {
        final enriched = await attendance.enrichVenueForMatch(m);
        if (!mounted) return;
        setState(() {
          _upcomingMatches = _upcomingMatches.map((x) => x.id == enriched.id ? enriched : x).toList();
          _pastMatches = _pastMatches.map((x) => x.id == enriched.id ? enriched : x).toList();
        });
      }
    } finally {
      _resolvingUnknown = false;
      if (mounted) {
        final hasUnknown = [..._upcomingMatches, ..._pastMatches]
            .any((m) => m.source != MatchSource.firestore && m.venueResolveStatus == VenueResolveStatus.unknown);
        if (hasUnknown) {
          Future<void>.delayed(const Duration(milliseconds: 100), _resolveUnknownInBackground);
        }
      }
    }
  }

  String _filtersSummaryLabel() {
    final source = switch (_sourceFilter) {
      MatchSource.firestore => 'Источник: приложение',
      MatchSource.apiFootball => 'Источник: API-Football',
      MatchSource.footballDataOrg => 'Источник: football-data.org',
      null => 'Источник: все',
    };
    final sort = _sort == MatchSort.startTimeAsc ? 'раньше->позже' : 'позже->раньше';
    final league = _leagueFilter ?? 'все лиги';
    final russia = _onlyRussia ? 'РПЛ/Россия' : 'все страны';
    return '$source · $league · $russia · $sort';
  }

  Future<void> _openFiltersSheet() async {
    MatchSource? tempSource = _sourceFilter;
    MatchSort tempSort = _sort;
    String? tempLeague = _leagueFilter;
    bool tempOnlyMy = _onlyMy;
    bool tempOnlyRussia = _onlyRussia;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Фильтры и сортировка', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Только мои матчи'),
                      value: tempOnlyMy,
                      onChanged: (v) => setModalState(() => tempOnlyMy = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Только Россия (РПЛ)'),
                      subtitle: const Text('По данным API: лига 235 и RFPL'),
                      value: tempOnlyRussia,
                      onChanged: (v) => setModalState(() {
                        tempOnlyRussia = v;
                        if (v) tempLeague = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<MatchSource?>(
                      value: tempSource,
                      decoration: const InputDecoration(labelText: 'Источник'),
                      items: const [
                        DropdownMenuItem<MatchSource?>(value: null, child: Text('Все источники')),
                        DropdownMenuItem<MatchSource?>(value: MatchSource.firestore, child: Text('Из приложения')),
                        DropdownMenuItem<MatchSource?>(value: MatchSource.apiFootball, child: Text('API-Football')),
                        DropdownMenuItem<MatchSource?>(value: MatchSource.footballDataOrg, child: Text('football-data.org')),
                      ],
                      onChanged: (v) => setModalState(() => tempSource = v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<MatchSort>(
                      value: tempSort,
                      decoration: const InputDecoration(labelText: 'Сортировка'),
                      items: const [
                        DropdownMenuItem(value: MatchSort.startTimeAsc, child: Text('Сначала ранние')),
                        DropdownMenuItem(value: MatchSort.startTimeDesc, child: Text('Сначала поздние')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => tempSort = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      value: tempLeague,
                      decoration: const InputDecoration(labelText: 'Лига'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Все лиги')),
                        ..._leagueOptions.map((l) => DropdownMenuItem<String?>(value: l, child: Text(l))),
                      ],
                      onChanged: (v) => setModalState(() => tempLeague = v),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                tempSource = null;
                                tempSort = MatchSort.startTimeAsc;
                                tempLeague = null;
                                tempOnlyMy = false;
                                tempOnlyRussia = false;
                              });
                            },
                            child: const Text('Сбросить'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Применить'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (changed == true) {
      setState(() {
        _sourceFilter = tempSource;
        _sort = tempSort;
        _leagueFilter = tempLeague;
        _onlyMy = tempOnlyMy;
        _onlyRussia = tempOnlyRussia;
      });
      _load(resetPages: true);
    }
  }
}

/// Статус подключения внешних API и подсказка, если ключи не заданы.
class _ApiMatchesBanner extends StatelessWidget {
  final List<MatchModel> matches;

  const _ApiMatchesBanner({required this.matches});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = context.read<AttendanceService>().footballApiConfig;
    final apiCount = matches.where((m) => m.source != MatchSource.firestore).length;
    final localCount = matches.length - apiCount;

    if (!config.hasAnyApiKey) {
      return Card(
        color: colorScheme.errorContainer.withOpacity(0.45),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_off_outlined, color: colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Реальные матчи из API не подключены',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                kIsWeb
                    ? 'В браузере файл .env из папки проекта не читается. Укажите ключи так:\n'
                        '• добавьте assets/env/local.env с ключами и строку `- assets/env/local.env` в pubspec.yaml, или\n'
                        '• запустите: flutter run -d chrome --dart-define=API_FOOTBALL_KEY=ВАШ_КЛЮЧ'
                    : 'Добавьте в корень проекта файл .env с API_FOOTBALL_KEY и/или FOOTBALL_DATA_TOKEN (в debug он подхватывается автоматически), либо используйте --dart-define. Подробности — README, раздел «Внешние API».',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final sourceParts = <String>[];
    if (config.apiFootballKey.isNotEmpty) sourceParts.add('API-Football');
    if (!kIsWeb && config.footballDataToken.isNotEmpty) sourceParts.add('football-data.org');
    final sourcesLabel = sourceParts.join(' · ');

    return Card(
      color: colorScheme.primaryContainer.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_done_rounded, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Реальные матчи из API включены',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${sourceParts.isEmpty ? "Источники: —" : "Источники: $sourcesLabel"} · в списке: $apiCount из сети, $localCount из приложения',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 8),
              Text(
                'В Chrome запросы к серверам API часто блокируются CORS. football-data.org из браузера отключён. '
                'Если матчей из сети нет — запустите: flutter run -d windows (или Android/iOS). Там же работает football-data.org.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
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

    final stadiumImage = match.effectiveVenueImageUrl;

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
                          if (match.source != MatchSource.firestore) ...[
                            if (match.league != null && match.league!.isNotEmpty) const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiary.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                match.source == MatchSource.apiFootball ? 'API-S' : 'F-D',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onTertiary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                              ),
                            ),
                          ],
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
                          if (match.effectiveStadium != null || match.venueDisplayLine != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.stadium_outlined, size: 16, color: Colors.white.withOpacity(0.9)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                match.effectiveStadium?.name ?? match.venueDisplayLine ?? '',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (match.venueStatusLabel != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          match.venueStatusLabel!,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.amber.shade200,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
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
