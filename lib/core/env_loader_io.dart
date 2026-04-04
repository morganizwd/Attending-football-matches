import 'dart:io' show File;

/// В debug на desktop/mobile читаем `.env` из текущей рабочей директории (корень проекта при `flutter run`).
Future<String?> loadDebugRootEnvFile() async {
  try {
    final f = File('.env');
    if (await f.exists()) {
      return await f.readAsString();
    }
  } catch (_) {}
  return null;
}
