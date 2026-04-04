import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:attending_football_matches/core/env_loader_stub.dart'
    if (dart.library.io) 'package:attending_football_matches/core/env_loader_io.dart' as env_io;

/// Загружает переменные окружения из ассетов и (в debug на не-web) из `.env` в корне проекта.
///
/// Приоритет первого вхождения ключа (flutter_dotenv): корневой `.env` (только debug + не-web),
/// затем `assets/env/local.env`, затем шаблон `assets/env/env.example`.
/// Ассет `.env` в корне не используем — он не в pubspec и даёт 404 в Chrome.
Future<void> loadDotEnv() async {
  final example = await rootBundle.loadString('assets/env/env.example');
  final parts = <String>[];

  if (!kIsWeb && kDebugMode) {
    final root = await env_io.loadDebugRootEnvFile();
    if (root != null && root.trim().isNotEmpty) {
      parts.add(root);
    }
  }

  try {
    parts.add(await rootBundle.loadString('assets/env/local.env'));
  } catch (_) {}
  parts.add(example);

  // Детерминированно сливаем переменные: берём первое непустое значение.
  final merged = <String, String>{};
  for (final part in parts) {
    for (final line in part.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#') || !trimmed.contains('=')) continue;
      final idx = trimmed.indexOf('=');
      final key = trimmed.substring(0, idx).trim();
      final value = trimmed.substring(idx + 1).trim();
      if (key.isEmpty) continue;
      final prev = merged[key]?.trim() ?? '';
      if (prev.isEmpty && value.isNotEmpty) {
        merged[key] = value;
      } else if (!merged.containsKey(key)) {
        merged[key] = value;
      }
    }
  }

  final combined = merged.entries.map((e) => '${e.key}=${e.value}').join('\n');
  dotenv.testLoad(fileInput: combined);
}
