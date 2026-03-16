import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:attending_football_matches/core/constants.dart';
import 'package:attending_football_matches/models/achievement.dart';
import 'package:attending_football_matches/models/stadium.dart';

class AchievementsAdminScreen extends StatefulWidget {
  const AchievementsAdminScreen({super.key});

  @override
  State<AchievementsAdminScreen> createState() => _AchievementsAdminScreenState();
}

class _AchievementsAdminScreenState extends State<AchievementsAdminScreen> {
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Достижения')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по названию',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection(FirestoreCollections.achievements).orderBy('requiredCount').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                if (_query.isNotEmpty) {
                  docs = docs.where((d) {
                    final a = Achievement.fromFirestore(d);
                    return a.title.toLowerCase().contains(_query);
                  }).toList();
                }
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events, size: 64),
                        const SizedBox(height: 12),
                        Text(
                          'Достижения не найдены',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Добавьте первое достижение',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final a = Achievement.fromFirestore(docs[i]);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: ListTile(
                        leading: _buildIcon(context, a),
                        title: Text(a.title),
                        subtitle: Text('${a.type} • ${a.requiredCount}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAchievementForm(context, achievement: a),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteAchievement(context, a.id),
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
        onPressed: () => _showAchievementForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, Achievement a) {
    if (a.iconUrl != null && a.iconUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(a.iconUrl!),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      );
    }
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(Icons.emoji_events, color: Theme.of(context).colorScheme.primary),
    );
  }

  Future<void> _showAchievementForm(BuildContext context, {Achievement? achievement}) async {
    final titleController = TextEditingController(text: achievement?.title ?? '');
    final descriptionController = TextEditingController(text: achievement?.description ?? '');
    final requiredCountController = TextEditingController(text: achievement != null ? '${achievement.requiredCount}' : '1');
    final iconUrlController = TextEditingController(text: achievement?.iconUrl ?? '');
    String type = achievement?.type ?? 'matches_total';
    String? stadiumId = achievement?.stadiumId;
    String? teamName = achievement?.teamName;

    List<Stadium> stadiums = [];
    final snap = await _firestore.collection(FirestoreCollections.stadiums).orderBy('name').get();
    stadiums = snap.docs.map((d) => Stadium.fromFirestore(d)).toList();

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
                  Text(
                    achievement == null ? 'Новое достижение' : 'Редактировать достижение',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Настройте правило и загрузите иконку, чтобы бейдж выглядел профессионально.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Название *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Описание'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: requiredCountController,
                    decoration: const InputDecoration(labelText: 'Необходимое количество *'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Тип условия *'),
                    items: const [
                      DropdownMenuItem(
                        value: 'matches_total',
                        child: Text('Всего посещённых матчей'),
                      ),
                      DropdownMenuItem(
                        value: 'matches_same_stadium',
                        child: Text('N матчей на одном стадионе'),
                      ),
                      DropdownMenuItem(
                        value: 'matches_same_team',
                        child: Text('N матчей с одной командой'),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => type = v ?? 'matches_total'),
                  ),
                  const SizedBox(height: 12),
                  if (type == 'matches_same_stadium')
                    DropdownButtonFormField<String>(
                      value: stadiumId,
                      decoration: const InputDecoration(labelText: 'Стадион'),
                      items: stadiums.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                      onChanged: (v) => setModalState(() => stadiumId = v),
                    ),
                  if (type == 'matches_same_team')
                    TextField(
                      controller: TextEditingController(text: teamName ?? ''),
                      decoration: const InputDecoration(labelText: 'Команда'),
                      onChanged: (v) => teamName = v.trim(),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: iconUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL иконки бейджа',
                      helperText: 'Опционально, изображение для достижения',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      final requiredStr = requiredCountController.text.trim();
                      final requiredCount = int.tryParse(requiredStr);
                      if (title.isEmpty || requiredCount == null || requiredCount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Введите название и корректное количество')),
                        );
                        return;
                      }
                      final data = {
                        'title': title,
                        'description': descriptionController.text.trim(),
                        'requiredCount': requiredCount,
                        'type': type,
                        'iconUrl': iconUrlController.text.trim().isEmpty ? null : iconUrlController.text.trim(),
                        'stadiumId': type == 'matches_same_stadium' ? stadiumId : null,
                        'teamName': type == 'matches_same_team' ? (teamName?.trim().isEmpty ?? true ? null : teamName) : null,
                      };
                      if (achievement != null) {
                        await _firestore.collection(FirestoreCollections.achievements).doc(achievement.id).update(data);
                      } else {
                        await _firestore.collection(FirestoreCollections.achievements).add(data);
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

  Future<void> _deleteAchievement(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить достижение?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) {
      await _firestore.collection(FirestoreCollections.achievements).doc(id).delete();
    }
  }
}

