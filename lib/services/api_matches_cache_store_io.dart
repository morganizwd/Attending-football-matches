import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:attending_football_matches/models/match_model.dart';

/// Кэш ответов внешних API в JSON на диске (Windows/Android/iOS/desktop).
///
/// В **debug** файл пишется в `<корень проекта>/cache/`, если найден `pubspec.yaml`
/// (обход вверх от [Directory.current] — удобно смотреть кэш в репозитории).
/// В **release** — только [getApplicationSupportDirectory] (у установленного приложения нет папки проекта).
class ApiMatchesCacheStore {
  ApiMatchesCacheStore._();

  static const _fileName = 'api_external_matches_cache.json';
  static const Duration diskTtl = Duration(hours: 24);

  /// Корень Flutter-проекта с `pubspec.yaml`, если удалось найти (только debug).
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

  static Future<File> _file() async {
    final project = await _debugProjectRoot();
    if (project != null) {
      final cacheDir = Directory(p.join(project.path, 'cache'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      return File(p.join(cacheDir.path, _fileName));
    }
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  static Future<Map<String, dynamic>?> _loadAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final text = await f.readAsString();
      final obj = jsonDecode(text);
      if (obj is Map<String, dynamic>) return obj;
      return null;
    } catch (e, st) {
      debugPrint('ApiMatchesCacheStore _loadAll: $e\n$st');
      return null;
    }
  }

  static Future<void> _saveAll(Map<String, dynamic> data) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(data));
  }

  static Future<List<MatchModel>?> readFresh({
    required String cacheKey,
    required Duration maxAge,
  }) async {
    final all = await _loadAll();
    if (all == null) return null;
    final entry = all[cacheKey];
    if (entry is! Map<String, dynamic>) return null;
    final atStr = entry['fetchedAt'] as String?;
    if (atStr == null) return null;
    final at = DateTime.tryParse(atStr);
    if (at == null) return null;
    if (DateTime.now().difference(at) > maxAge) return null;
    final list = entry['matches'] as List<dynamic>?;
    if (list == null) return null;
    final out = <MatchModel>[];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        try {
          out.add(MatchModel.fromJsonCache(item));
        } catch (e, st) {
          debugPrint('ApiMatchesCacheStore fromJsonCache: $e\n$st');
        }
      }
    }
    return out;
  }

  static Future<void> write({
    required String cacheKey,
    required List<MatchModel> matches,
  }) async {
    try {
      final all = await _loadAll() ?? <String, dynamic>{};
      final now = DateTime.now();
      all[cacheKey] = {
        'fetchedAt': now.toIso8601String(),
        'matches': matches.map((m) => m.toJsonCache()).toList(),
      };
      _pruneOldEntries(all, now);
      await _saveAll(all);
    } catch (e, st) {
      debugPrint('ApiMatchesCacheStore write: $e\n$st');
    }
  }

  static void _pruneOldEntries(Map<String, dynamic> all, DateTime now) {
    const maxAge = Duration(days: 7);
    all.removeWhere((key, value) {
      if (value is! Map<String, dynamic>) return true;
      final at = DateTime.tryParse(value['fetchedAt'] as String? ?? '');
      if (at == null) return false;
      return now.difference(at) > maxAge;
    });
  }
}
