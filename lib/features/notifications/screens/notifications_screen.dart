import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';

final notificationsProvider = FutureProvider<List<dynamic>>((ref) async {
  final data = await ref.watch(apiServiceProvider).getNotifications();
  return data['notifications'] as List? ?? [];
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(apiServiceProvider).markAllNotificationsRead();
              ref.invalidate(notificationsProvider);
            },
            child: const Text('Mark all read', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('No notifications', style: TextStyle(color: Colors.grey)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (_, i) {
              final n = notifications[i] as Map;
              final isRead = n['is_read'] == true;
              final createdAt = n['created_at'] != null ? DateTime.parse(n['created_at']) : null;

              IconData icon;
              Color iconColor;
              switch (n['type'] as String? ?? '') {
                case 'payslip': icon = Icons.receipt_long_outlined; iconColor = AppTheme.success; break;
                case 'leave_approved': icon = Icons.check_circle_outline; iconColor = AppTheme.success; break;
                case 'leave_rejected': icon = Icons.cancel_outlined; iconColor = AppTheme.error; break;
                case 'leave_request': icon = Icons.beach_access_outlined; iconColor = AppTheme.warning; break;
                case 'attendance': icon = Icons.access_time_outlined; iconColor = AppTheme.info; break;
                default: icon = Icons.notifications_outlined; iconColor = AppTheme.primary;
              }

              return Dismissible(
                key: Key(n['id'] ?? '$i'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppTheme.error,
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await ref.read(apiServiceProvider).markNotificationRead(n['id']);
                  ref.invalidate(notificationsProvider);
                },
                child: InkWell(
                  onTap: () async {
                    if (!isRead) {
                      await ref.read(apiServiceProvider).markNotificationRead(n['id']);
                      ref.invalidate(notificationsProvider);
                    }
                  },
                  child: Container(
                    color: isRead ? null : AppTheme.primary.withOpacity(0.04),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: iconColor.withOpacity(0.12), shape: BoxShape.circle),
                        child: Icon(icon, color: iconColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(n['title'] ?? '',
                              style: TextStyle(fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, fontSize: 14))),
                          if (!isRead) Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                          ),
                        ]),
                        const SizedBox(height: 3),
                        Text(n['message'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (createdAt != null) ...[
                          const SizedBox(height: 4),
                          Text(DateFormat('dd MMM · hh:mm a').format(createdAt),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                      ])),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
