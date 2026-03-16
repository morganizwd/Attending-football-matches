import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attending_football_matches/services/auth_service.dart';
import 'package:attending_football_matches/services/attendance_service.dart';
import 'package:attending_football_matches/services/location_service.dart';
import 'package:attending_football_matches/services/notification_service.dart';
import 'package:attending_football_matches/models/match_model.dart';
import 'package:attending_football_matches/features/matches/widgets/stadium_map_sheet.dart';
import 'package:intl/intl.dart';
import 'package:attending_football_matches/core/constants.dart';

class MatchDetailScreen extends StatefulWidget {
  final MatchModel match;

  const MatchDetailScreen({super.key, required this.match});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  bool _hasIntent = false;
  bool _hasAttendance = false;
  bool _loading = true;
  bool _intentLoading = false;
  bool _checkingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;
    final attendance = context.read<AttendanceService>();
    final hasIntent = await attendance.hasIntent(uid, widget.match.id);
    final hasAttendance = await attendance.hasAttendance(uid, widget.match.id);
    if (mounted) {
      setState(() {
        _hasIntent = hasIntent;
        _hasAttendance = hasAttendance;
        _loading = false;
      });
    }
  }

  Future<void> _toggleIntent() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;
    setState(() => _intentLoading = true);
    final attendance = context.read<AttendanceService>();
    final notifications = context.read<NotificationService>();
    if (_hasIntent) {
      await attendance.removeIntent(uid, widget.match.id);
      notifications.cancelReminder(widget.match.id.hashCode);
    } else {
      await attendance.addIntent(uid, widget.match.id, reminderEnabled: true);
      await notifications.scheduleMatchReminder(
        id: widget.match.id.hashCode,
        title: 'Матч сегодня',
        body: '${widget.match.homeTeam} — ${widget.match.awayTeam}. Не забудьте включить геолокацию у стадиона.',
        matchStart: widget.match.startTime,
      );
    }
    if (mounted) setState(() => _hasIntent = !_hasIntent);
    setState(() => _intentLoading = false);
  }

  Future<void> _checkLocationNow() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;
    if (widget.match.stadium == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('У матча не указан стадион')));
      return;
    }
    final attendance = context.read<AttendanceService>();
    if (!attendance.isWithinTimeWindow(widget.match.startTime)) {
      final start = widget.match.startTime.subtract(Duration(minutes: minutesBeforeMatchStart));
      final end = widget.match.startTime.add(Duration(minutes: minutesAfterMatchStart));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Проверка возможна с ${DateFormat('HH:mm').format(start)} по ${DateFormat('HH:mm').format(end)} в день матча',
          ),
        ),
      );
      return;
    }
    setState(() => _checkingLocation = true);
    final location = context.read<LocationService>();
    try {
      final recorded = await attendance.checkAndRecordAttendance(uid, widget.match, location);
      if (!mounted) return;
      setState(() => _checkingLocation = false);
      if (recorded) {
        setState(() => _hasAttendance = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Посещение засчитано!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(location.error ?? 'Вы не в радиусе стадиона (${stadiumProximityMeters.toInt()} м)')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось проверить геолокацию: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Матч')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (m.stadium?.imageUrl != null && m.stadium!.imageUrl!.isNotEmpty)
                          SizedBox(
                            height: 220,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  m.stadium!.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, _, __) => Container(
                                    color: colorScheme.surfaceVariant,
                                    child: const Icon(Icons.stadium_outlined, size: 48),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.2),
                                        Colors.black.withOpacity(0.65),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 18,
                                  right: 18,
                                  bottom: 16,
                                  child: Text(
                                    '${m.homeTeam} — ${m.awayTeam}',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              if (m.league != null && m.league!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    m.league!,
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                ),
                              const SizedBox(height: 12),
                              if (m.stadium?.imageUrl == null || m.stadium!.imageUrl!.isEmpty)
                                Text(
                                  '${m.homeTeam} — ${m.awayTeam}',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              const SizedBox(height: 16),
                              ListTile(
                                leading: const Icon(Icons.calendar_today),
                                title: const Text('Дата и время'),
                                subtitle: Text(dateFormat.format(m.startTime)),
                              ),
                              if (m.stadium != null) ...[
                                ListTile(
                                  leading: const Icon(Icons.place),
                                  title: Text(m.stadium!.name),
                                  subtitle: Text(m.stadium!.address ?? m.stadium!.city ?? ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.map),
                                    onPressed: () => StadiumMapSheet.show(context, m.stadium!),
                                  ),
                                ),
                                if (m.stadium!.mapImageUrl != null && m.stadium!.mapImageUrl!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Карта стадиона',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: AspectRatio(
                                      aspectRatio: 4 / 3,
                                      child: Image.network(
                                        m.stadium!.mapImageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, _, __) => Container(
                                          color: colorScheme.surfaceVariant,
                                          child: const Center(
                                            child: Icon(Icons.broken_image_outlined, size: 40),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_hasAttendance)
                    Card(
                      color: colorScheme.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: colorScheme.tertiary, size: 32),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text('Посещение засчитано. Матч в вашей истории.'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    FilledButton.icon(
                      onPressed: _intentLoading ? null : _toggleIntent,
                      icon: _hasIntent ? const Icon(Icons.cancel) : const Icon(Icons.check_circle_outline),
                      label: Text(_hasIntent ? 'Отменить намерение' : 'Планирую посетить'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _checkingLocation ? null : _checkLocationNow,
                      icon: _checkingLocation ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
                      label: const Text('Проверить геолокацию сейчас'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
