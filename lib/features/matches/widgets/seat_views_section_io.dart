import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:attending_football_matches/models/seat_view_report.dart';
import 'package:attending_football_matches/services/seat_view_storage.dart';

class SeatViewsSection extends StatefulWidget {
  final String matchId;

  const SeatViewsSection({super.key, required this.matchId});

  @override
  State<SeatViewsSection> createState() => _SeatViewsSectionState();
}

class _SeatViewsSectionState extends State<SeatViewsSection> {
  List<SeatViewReport> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list = await SeatViewStorageService.listForMatch(widget.matchId);
    if (mounted) {
      setState(() {
        _reports = list;
        _loading = false;
      });
    }
  }

  Future<void> _openAddSheet() async {
    final noteController = TextEditingController();
    var goodView = true;
    var farFromPitch = false;
    String? pickedPath;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Вид с вашего места', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Фото и описание хранятся только на устройстве (папка проекта в режиме разработки).',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Где сидели (необязательно)',
                        hintText: 'Сектор, ряд, место',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Хороший вид'),
                      subtitle: const Text('С места нормально смотреть игру'),
                      value: goodView,
                      onChanged: (v) => setModal(() => goodView = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Далеко от поля'),
                      subtitle: const Text('Если место дальше от центра поля'),
                      value: farFromPitch,
                      onChanged: (v) => setModal(() => farFromPitch = v),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final r = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          allowMultiple: false,
                          withData: false,
                        );
                        if (r != null && r.files.isNotEmpty) {
                          final p = r.files.single.path;
                          setModal(() => pickedPath = p);
                        }
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(pickedPath == null ? 'Выбрать фото' : 'Фото выбрано'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: pickedPath == null
                          ? null
                          : () async {
                              final rep = await SeatViewStorageService.addReport(
                                matchId: widget.matchId,
                                sourceImagePath: pickedPath!,
                                seatNote: noteController.text,
                                goodView: goodView,
                                farFromPitch: farFromPitch,
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx, rep != null);
                              }
                            },
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено локально')));
      }
    } else if (saved == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить (проверьте файл)')),
      );
    }
  }

  Future<void> _confirmDelete(SeatViewReport r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить отчёт?'),
        content: const Text('Фото и запись будут удалены с устройства.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) {
      await SeatViewStorageService.deleteReport(r.id);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.chair_outlined, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Вид с места',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _openAddSheet,
              icon: const Icon(Icons.add_a_photo_outlined, size: 20),
              label: const Text('Добавить'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_reports.isEmpty)
          Card(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Пока нет отчётов. Сфотографируйте вид с трибуны и оцените место.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          )
        else
          ..._reports.map((r) => _ReportCard(
                report: r,
                dateFmt: dateFmt,
                onDelete: () => _confirmDelete(r),
              )),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final SeatViewReport report;
  final DateFormat dateFmt;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.report,
    required this.dateFmt,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<String?>(
            future: SeatViewStorageService.absoluteImagePath(report),
            builder: (context, snap) {
              final path = snap.data;
              if (path == null) {
                return SizedBox(
                  height: 160,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined, color: colorScheme.outline, size: 40),
                  ),
                );
              }
              return AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined, size: 40),
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateFmt.format(report.createdAt),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                      tooltip: 'Удалить',
                    ),
                  ],
                ),
                if (report.seatNote != null && report.seatNote!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(report.seatNote!, style: Theme.of(context).textTheme.bodyLarge),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                      avatar: Icon(
                        report.goodView ? Icons.thumb_up_outlined : Icons.thumb_down_outlined,
                        size: 18,
                      ),
                      label: Text(report.goodView ? 'Хороший вид' : 'Вид так себе'),
                    ),
                    Chip(
                      avatar: Icon(
                        report.farFromPitch ? Icons.straighten : Icons.sports_soccer,
                        size: 18,
                      ),
                      label: Text(report.farFromPitch ? 'Далеко от поля' : 'Ближе к полю'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
