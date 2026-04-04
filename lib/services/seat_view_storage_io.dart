import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:attending_football_matches/models/seat_view_report.dart';

/// Фото и manifest в `<проект>/seat_views/` (debug) или в каталоге приложения (release).
class SeatViewStorageService {
  SeatViewStorageService._();

  static const _manifestName = 'seat_views_manifest.json';
  static const _uuid = Uuid();

  static bool get isSupported => true;

  static Future<Directory?> _debugProjectRoot() async {
    if (kIsWeb || !kDebugMode) return null;
    try {
      var dir = Directory.current;
      for (var i = 0; i < 16; i++) {
        final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
        if (await pubspec.exists()) return dir;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {}
    return null;
  }

  static Future<Directory> _baseDir() async {
    final project = await _debugProjectRoot();
    if (project != null) {
      final d = Directory(p.join(project.path, 'seat_views'));
      if (!await d.exists()) await d.create(recursive: true);
      return d;
    }
    final support = await getApplicationSupportDirectory();
    final d = Directory(p.join(support.path, 'seat_views'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<File> _manifestFile() async {
    final base = await _baseDir();
    return File(p.join(base.path, _manifestName));
  }

  static Future<List<SeatViewReport>> _loadAll() async {
    try {
      final f = await _manifestFile();
      if (!await f.exists()) return [];
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>?;
      final list = map?['reports'] as List<dynamic>? ?? [];
      return list
          .map((e) => SeatViewReport.fromJson(e as Map<String, dynamic>))
          .where((r) => r.id.isNotEmpty && r.imageFileName.isNotEmpty)
          .toList();
    } catch (e, st) {
      debugPrint('SeatViewStorageService _loadAll: $e\n$st');
      return [];
    }
  }

  static Future<void> _saveAll(List<SeatViewReport> reports) async {
    final f = await _manifestFile();
    await f.writeAsString(
      jsonEncode({
        'reports': reports.map((r) => r.toJson()).toList(),
      }),
    );
  }

  static Future<List<SeatViewReport>> listForMatch(String matchId) async {
    final all = await _loadAll();
    return all
        .where((r) => r.matchId == matchId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<SeatViewReport?> addReport({
    required String matchId,
    required String sourceImagePath,
    String? seatNote,
    required bool goodView,
    required bool farFromPitch,
  }) async {
    try {
      final src = File(sourceImagePath);
      if (!await src.exists()) return null;
      final id = _uuid.v4();
      final ext = p.extension(sourceImagePath).toLowerCase();
      final safeExt = (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp') ? ext : '.jpg';
      final imageFileName = 'view_$id$safeExt';
      final base = await _baseDir();
      final dest = File(p.join(base.path, imageFileName));
      await src.copy(dest.path);

      final report = SeatViewReport(
        id: id,
        matchId: matchId,
        createdAt: DateTime.now(),
        imageFileName: imageFileName,
        seatNote: seatNote?.trim().isEmpty == true ? null : seatNote?.trim(),
        goodView: goodView,
        farFromPitch: farFromPitch,
      );
      final all = await _loadAll();
      all.add(report);
      await _saveAll(all);
      return report;
    } catch (e, st) {
      debugPrint('SeatViewStorageService addReport: $e\n$st');
      return null;
    }
  }

  static Future<void> deleteReport(String reportId) async {
    try {
      final all = await _loadAll();
      final idx = all.indexWhere((r) => r.id == reportId);
      if (idx < 0) return;
      final removed = all.removeAt(idx);
      final base = await _baseDir();
      final img = File(p.join(base.path, removed.imageFileName));
      if (await img.exists()) await img.delete();
      await _saveAll(all);
    } catch (e, st) {
      debugPrint('SeatViewStorageService deleteReport: $e\n$st');
    }
  }

  static Future<String?> absoluteImagePath(SeatViewReport report) async {
    final base = await _baseDir();
    final f = File(p.join(base.path, report.imageFileName));
    if (await f.exists()) return f.path;
    return null;
  }
}
