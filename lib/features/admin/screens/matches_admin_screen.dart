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
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection(FirestoreCollections.matches).orderBy('startTime', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
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
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(m.title),
                  subtitle: Text('${dateFormat.format(m.startTime)} • ${stadium?.name ?? m.stadiumId}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showMatchForm(context, match: MatchModel.fromFirestore(docs[i], stadium: stadium)),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMatchForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showMatchForm(BuildContext context, {MatchModel? match}) async {
    DateTime date = match?.startTime ?? DateTime.now().add(const Duration(days: 1));
    final homeController = TextEditingController(text: match?.homeTeam ?? '');
    final awayController = TextEditingController(text: match?.awayTeam ?? '');
    final leagueController = TextEditingController(text: match?.league ?? '');
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
                  const SizedBox(height: 16),
                  TextField(controller: homeController, decoration: const InputDecoration(labelText: 'Хозяева *')),
                  const SizedBox(height: 12),
                  TextField(controller: awayController, decoration: const InputDecoration(labelText: 'Гости *')),
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
                      final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (d != null) {
                        final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(date));
                        if (t != null) setModalState(() => date = DateTime(d.year, d.month, d.day, t.hour, t.minute));
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
                      final data = {
                        'homeTeam': home,
                        'awayTeam': away,
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
}
