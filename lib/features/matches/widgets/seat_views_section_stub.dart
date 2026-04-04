import 'package:flutter/material.dart';

/// Web: локальные файлы недоступны.
class SeatViewsSection extends StatelessWidget {
  final String matchId;

  const SeatViewsSection({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey<String>(matchId),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Отчёты «вид с места» с фото доступны в приложении Windows, Android или iOS (локальные файлы, без Firebase).',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
