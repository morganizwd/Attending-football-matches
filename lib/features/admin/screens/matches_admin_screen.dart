import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attending_football_matches/models/match_model.dart';
import 'package:attending_football_matches/models/stadium.dart';
import 'package:attending_football_matches/core/constants.dart';
import 'package:intl/intl.dart';

class MatchesAdminScreen extends StatefulWidget {
  const MatchesAdminScreen({super.key});

  @override
  State<MatchesAdminScreen> createState() => _MatchesAdminScreenState();
}

class _MatchesAdminScreenState extends State<MatchesAdminScreen> {
  final _firestore = FirebaseFirestore.instance;
  List<Stadium> _stadiums = [];
  bool _showUpcoming = true;
  bool _showFinished = false;

  @override
  void initState() {
    super.initState();
    _loadStadiums();
  }

  Future<void> _loadStadiums() async {
    final snap = await _firestore.collection(FirestoreCollections.stadiums).orderBy('name').get();
    setState(() => _stadiums = snap.docs.map((d) => Stadium.fromFirestore(d)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Матчи')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Предстоящие / идущие'),
                  selected: _showUpcoming,
                  onSelected: (v) => setState(() => _showUpcoming = v),
                ),
                FilterChip(
                  label: const Text('Завершённые'),
                  selected: _showFinished,
                  onSelected: (v) => setState(() => _showFinished = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection(FirestoreCollections.matches).orderBy('startTime', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final allDocs = snapshot.data!.docs;
                final now = DateTime.now();
                final docs = allDocs.where((d) {
                  final m = MatchModel.fromFirestore(d);
                  final start = m.startTime;
                  final end = start.add(const Duration(minutes: minutesAfterMatchStart));
                  final isOngoing = !now.isBefore(start) && !now.isAfter(end);
                  final isFuture = now.isBefore(start);
                  final isPastDone = now.isAfter(end);
                  final upcoming = isFuture || isOngoing;
                  if (_showUpcoming && ! _showFinished) return upcoming;
                  if (_showFinished && ! _showUpcoming) return isPastDone;
                  if (_showUpcoming && _showFinished) return true;
                  // если ничего не выбрано, показываем всё
                  return true;
                }).toList();

                final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sports_soccer, size: 64),
                        const SizedBox(height: 16),
                        const Text('Нет матчей'),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _showMatchForm(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить матч'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final m = MatchModel.fromFirestore(docs[i]);
                    Stadium? stadium;
                    try {
                      stadium = _stadiums.firstWhere((s) => s.id == m.stadiumId);
                    } catch (_) {}
                    final start = m.startTime;
                    final end = start.add(const Duration(minutes: minutesAfterMatchStart));
                    final isOngoing = !now.isBefore(start) && !now.isAfter(end);
                    final isFuture = now.isBefore(start);
                    final isPastDone = now.isAfter(end);
                    String status;
                    if (isOngoing) {
                      status = 'Идёт сейчас';
                    } else if (isFuture) {
                      status = 'Предстоящий';
                    } else if (isPastDone) {
                      status = 'Завершён';
                    } else {
                      status = 'Матч';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: const Icon(Icons.sports_soccer),
                        ),
                        title: Text(m.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${dateFormat.format(m.startTime)} • ${stadium?.name ?? m.stadiumId}'),
                            const SizedBox(height: 4),
                            Text(
                              status,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isOngoing
                                        ? Theme.of(context).colorScheme.tertiary
                                        : isFuture
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showMatchForm(
                                context,
                                match: MatchModel.fromFirestore(docs[i], stadium: stadium),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteMatch(context, m.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMatchForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showMatchForm(BuildContext context, {MatchModel? match}) async {
    final now = DateTime.now();
    final defaultFuture = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    DateTime date = match?.startTime ?? defaultFuture;
    var pastMode = false;
    if (match != null) {
      final matchEnd = match.startTime.add(const Duration(minutes: minutesAfterMatchStart));
      pastMode = now.isAfter(matchEnd);
    }
    final homeController = TextEditingController(text: match?.homeTeam ?? '');
    final awayController = TextEditingController(text: match?.awayTeam ?? '');
    final leagueController = TextEditingController(text: match?.league ?? '');
    final homeLogoController = TextEditingController(text: match?.homeTeamLogo ?? '');
    final awayLogoController = TextEditingController(text: match?.awayTeamLogo ?? '');
    String? selectedStadiumId = match?.stadiumId.isEmpty == true ? null : match?.stadiumId;
    if (selectedStadiumId == null && _stadiums.isNotEmpty) selectedStadiumId = _stadiums.first.id;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(match == null ? 'Новый матч' : 'Редактировать матч', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Предстоящий'),
                        icon: Icon(Icons.schedule, size: 18),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Прошедший'),
                        icon: Icon(Icons.history, size: 18),
                      ),
                    ],
                    selected: {pastMode},
                    onSelectionChanged: (Set<bool> next) {
                      setModalState(() {
                        pastMode = next.first;
                        if (pastMode) {
                          if (!date.isBefore(now)) {
                            date = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
                          }
                        } else {
                          final todayStart = DateTime(now.year, now.month, now.day);
                          if (!date.isAfter(todayStart)) {
                            date = todayStart.add(const Duration(days: 1));
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      pastMode
                          ? 'Дата и время в прошлом — матч попадёт в завершённые и в историю посещений.'
                          : 'Заполните команды, логотипы и дату матча.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: homeController, decoration: const InputDecoration(labelText: 'Хозяева *')),
                  const SizedBox(height: 12),
                  TextField(controller: awayController, decoration: const InputDecoration(labelText: 'Гости *')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: homeLogoController,
                          decoration: const InputDecoration(
                            labelText: 'URL эмблемы хозяев',
                            helperText: 'Опционально, ссылка на изображение',
                          ),
                          keyboardType: TextInputType.url,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: awayLogoController,
                          decoration: const InputDecoration(
                            labelText: 'URL эмблемы гостей',
                            helperText: 'Опционально',
                          ),
                          keyboardType: TextInputType.url,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: leagueController, decoration: const InputDecoration(labelText: 'Лига')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStadiumId,
                    decoration: const InputDecoration(labelText: 'Стадион *'),
                    items: _stadiums.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                    onChanged: (v) => setModalState(() => selectedStadiumId = v),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text('Дата и время: ${DateFormat('dd.MM.yyyy HH:mm').format(date)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final todayStart = DateTime(now.year, now.month, now.day);
                      final firstDate = pastMode
                          ? now.subtract(const Duration(days: 365 * 15))
                          : todayStart;
                      final lastDate =
                          pastMode ? now : todayStart.add(const Duration(days: 365 * 2));
                      var initial = date;
                      if (initial.isBefore(firstDate)) initial = firstDate;
                      if (initial.isAfter(lastDate)) initial = lastDate;
                      final d = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: firstDate,
                        lastDate: lastDate,
                      );
                      if (d != null) {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(date),
                        );
                        if (t != null) {
                          setModalState(() {
                            date = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () async {
                      final home = homeController.text.trim();
                      final away = awayController.text.trim();
                      if (home.isEmpty || away.isEmpty || selectedStadiumId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните команды и стадион')));
                        return;
                      }
                      final homeLogo = homeLogoController.text.trim().isEmpty ? null : homeLogoController.text.trim();
                      final awayLogo = awayLogoController.text.trim().isEmpty ? null : awayLogoController.text.trim();
                      final data = {
                        'homeTeam': home,
                        'awayTeam': away,
                        'homeTeamLogo': homeLogo,
                        'awayTeamLogo': awayLogo,
                        'league': leagueController.text.trim().isEmpty ? null : leagueController.text.trim(),
                        'stadiumId': selectedStadiumId,
                        'startTime': Timestamp.fromDate(date),
                        'isActive': true,
                      };
                      if (match != null) {
                        await _firestore.collection(FirestoreCollections.matches).doc(match.id).update(data);
                      } else {
                        await _firestore.collection(FirestoreCollections.matches).add(data);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteMatch(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить матч?'),
        content: const Text('Матч будет удалён без возможности восстановления. Продолжить?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) {
      await _firestore.collection(FirestoreCollections.matches).doc(id).delete();
    }
  }
}
