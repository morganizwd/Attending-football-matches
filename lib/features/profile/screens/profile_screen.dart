import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attending_football_matches/services/auth_service.dart';
import 'package:attending_football_matches/services/theme_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final theme = context.watch<ThemeService>();
    final user = auth.currentUser;
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: user == null
          ? const Center(child: Text('Не авторизован'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.white.withOpacity(0.22),
                          backgroundImage: profile?.photoUrl != null ? NetworkImage(profile!.photoUrl!) : null,
                          child: profile?.photoUrl == null
                              ? Text(
                                  (profile?.displayName ?? user.email ?? '?').substring(0, 1).toUpperCase(),
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: Colors.white,
                                      ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          profile?.displayName ?? user.email ?? 'Пользователь',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                              ),
                        ),
                        if (user.email != null && user.email!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              user.email!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.86),
                                  ),
                            ),
                          ),
                        if (auth.isAdmin)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Chip(
                              avatar: Icon(
                                Icons.admin_panel_settings,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              label: const Text('Администратор'),
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('Редактировать профиль'),
                          subtitle: const Text('Имя и фото профиля'),
                          onTap: () => _showEditProfile(context, auth),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.color_lens_outlined),
                          title: const Text('Тема приложения'),
                          subtitle: Text(_themeLabel(theme.mode)),
                          onTap: () => _showThemeSheet(context, theme),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                          title: Text('Выйти', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          onTap: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Выйти?'),
                                content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Выйти')),
                                ],
                              ),
                            );
                            if (ok == true && context.mounted) await auth.signOut();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showEditProfile(BuildContext context, AuthService auth) {
    final profile = auth.profile;
    final user = auth.currentUser;
    final nameController = TextEditingController(text: profile?.displayName ?? user?.displayName ?? '');
    final photoController = TextEditingController(text: profile?.photoUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать профиль'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Имя'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: photoController,
              decoration: const InputDecoration(
                labelText: 'URL фото профиля',
                hintText: 'https://...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              await auth.updateProfile(
                displayName: nameController.text.trim(),
                photoUrl: photoController.text.trim().isEmpty ? null : photoController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Светлая';
      case ThemeMode.dark:
        return 'Тёмная';
      case ThemeMode.system:
      default:
        return 'Как в системе';
    }
  }

  void _showThemeSheet(BuildContext context, ThemeService theme) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Как в системе'),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: theme.mode,
                  onChanged: (v) {
                    if (v != null) theme.setMode(v);
                    Navigator.pop(ctx);
                  },
                ),
                onTap: () {
                  theme.setMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('Светлая'),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: theme.mode,
                  onChanged: (v) {
                    if (v != null) theme.setMode(v);
                    Navigator.pop(ctx);
                  },
                ),
                onTap: () {
                  theme.setMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('Тёмная'),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: theme.mode,
                  onChanged: (v) {
                    if (v != null) theme.setMode(v);
                    Navigator.pop(ctx);
                  },
                ),
                onTap: () {
                  theme.setMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
