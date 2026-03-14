import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attending_football_matches/services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
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
                  const SizedBox(height: 24),
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: profile?.photoUrl != null ? NetworkImage(profile!.photoUrl!) : null,
                    child: profile?.photoUrl == null
                        ? Text(
                            (profile?.displayName ?? user.email ?? '?').substring(0, 1).toUpperCase(),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profile?.displayName ?? user.email ?? 'Пользователь',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (user.email != null && user.email!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        user.email!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  if (auth.isAdmin)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Chip(
                        avatar: const Icon(Icons.admin_panel_settings, size: 18, color: Colors.white),
                        label: const Text('Администратор'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    ),
                  const SizedBox(height: 32),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Редактировать профиль'),
                    onTap: () => _showEditProfile(context, auth),
                  ),
                  const Divider(),
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
    );
  }

  void _showEditProfile(BuildContext context, AuthService auth) {
    final nameController = TextEditingController(text: auth.profile?.displayName ?? auth.currentUser?.displayName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать профиль'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Имя'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              await auth.updateProfile(displayName: nameController.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
