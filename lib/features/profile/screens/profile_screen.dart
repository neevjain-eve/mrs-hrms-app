import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/profile/edit')),
        ],
      ),
      body: ListView(
        children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Column(children: [
              CircleAvatar(
                radius: 44,
                backgroundImage: user?.photoUrl != null ? CachedNetworkImageProvider(user!.photoUrl!) : null,
                backgroundColor: Colors.white24,
                child: user?.photoUrl == null
                    ? Text('${user?.firstName?[0] ?? ''}${user?.lastName?[0] ?? ''}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white))
                    : null,
              ),
              const SizedBox(height: 12),
              Text('${user?.firstName ?? ''} ${user?.lastName ?? ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(user?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: Text((user?.role ?? '').replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _MenuCard([
                _MenuItem(Icons.person_outline, 'Personal Information', () => context.push('/profile/edit')),
                _MenuItem(Icons.lock_outline, 'Change Password', () => context.push('/profile/change-password')),
                _MenuItem(Icons.notifications_outlined, 'Notification Settings', () {}),
              ]),
              const SizedBox(height: 12),

              // Dark mode toggle
              Card(
                child: ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, color: AppTheme.primary, size: 20),
                  ),
                  title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: Switch(
                    value: isDark,
                    onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                    activeColor: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _MenuCard([
                _MenuItem(Icons.help_outline, 'Help & Support', () {}),
                _MenuItem(Icons.info_outline, 'About MRS HRMS', () {}),
              ]),
              const SizedBox(height: 12),

              Card(
                child: ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.logout, color: AppTheme.error, size: 20),
                  ),
                  title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.error)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) ref.read(authProvider.notifier).logout();
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text('MRS HRMS v1.0.0', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              const SizedBox(height: 8),
            ]),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard(this.items);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(children: [
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(item.icon, color: AppTheme.primary, size: 20),
              ),
              title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
              onTap: item.onTap,
            ),
            if (i < items.length - 1) const Divider(height: 1, indent: 70),
          ]);
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem(this.icon, this.label, this.onTap);
}
