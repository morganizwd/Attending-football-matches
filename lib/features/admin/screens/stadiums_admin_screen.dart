import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attending_football_matches/models/stadium.dart';
import 'package:attending_football_matches/core/constants.dart';

class StadiumsAdminScreen extends StatefulWidget {
  const StadiumsAdminScreen({super.key});

  @override
  State<StadiumsAdminScreen> createState() => _StadiumsAdminScreenState();
}

class _StadiumsAdminScreenState extends State<StadiumsAdminScreen> {
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Стадионы')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection(FirestoreCollections.stadiums).orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stadium, size: 64),
                  const SizedBox(height: 16),
                  const Text('Нет стадионов'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showStadiumForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить стадион'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final stadium = Stadium.fromFirestore(docs[i]);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(stadium.name),
                  subtitle: Text(stadium.city ?? stadium.address ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showStadiumForm(context, stadium: stadium)),
                      IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteStadium(context, stadium.id)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStadiumForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showStadiumForm(BuildContext context, {Stadium? stadium}) async {
    final nameController = TextEditingController(text: stadium?.name ?? '');
    final cityController = TextEditingController(text: stadium?.city ?? '');
    final addressController = TextEditingController(text: stadium?.address ?? '');
    final latController = TextEditingController(text: stadium != null ? '${stadium.latitude}' : '');
    final lonController = TextEditingController(text: stadium != null ? '${stadium.longitude}' : '');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(stadium == null ? 'Новый стадион' : 'Редактировать стадион', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Название *')),
              const SizedBox(height: 12),
              TextField(controller: cityController, decoration: const InputDecoration(labelText: 'Город')),
              const SizedBox(height: 12),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Адрес')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: latController, decoration: const InputDecoration(labelText: 'Широта *'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: lonController, decoration: const InputDecoration(labelText: 'Долгота *'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final lat = double.tryParse(latController.text.replaceAll(',', '.'));
                  final lon = double.tryParse(lonController.text.replaceAll(',', '.'));
                  if (name.isEmpty || lat == null || lon == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните название и координаты')));
                    return;
                  }
                  final data = {
                    'name': name,
                    'city': cityController.text.trim().isEmpty ? null : cityController.text.trim(),
                    'address': addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                    'latitude': lat,
                    'longitude': lon,
                  };
                  if (stadium != null) {
                    await _firestore.collection(FirestoreCollections.stadiums).doc(stadium.id).update(data);
                  } else {
                    await _firestore.collection(FirestoreCollections.stadiums).add(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteStadium(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить стадион?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) await _firestore.collection(FirestoreCollections.stadiums).doc(id).delete();
  }
}
