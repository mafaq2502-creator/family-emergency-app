import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/app_notification.dart';
import '../../../models/family_group.dart';
import '../../../services/app_notification_service.dart';
import '../../../core/widgets/light_ui.dart';
import 'notification_center_screen.dart';

/// A compact in-place inbox opened from the notification bell.
/// It deliberately does not navigate away from the current tab.
Future<void> showNotificationBanner(
  BuildContext context,
  User user, {
  List<FamilyGroup> groups = const [],
}) {
  final service = AppNotificationService();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss notifications',
    barrierColor: Colors.black54,
    pageBuilder: (context, _, _) => SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            color: Colors.transparent,
            child: _NotificationBanner(
              user: user,
              service: service,
              groups: groups,
            ),
          ),
        ),
      ),
    ),
  );
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({
    required this.user,
    required this.service,
    required this.groups,
  });
  final User user;
  final AppNotificationService service;
  final List<FamilyGroup> groups;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxHeight: 430),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? kDarkCard
          : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: StreamBuilder<List<AppNotification>>(
      stream: service.watch(user),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <AppNotification>[];
        final unread = notifications.where((item) => !item.isRead).length;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_rounded, color: kEmerald),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (unread > 0)
                    TextButton(
                      onPressed: () => service.markAllRead(user),
                      child: const Text('Read all'),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationCenterScreen(groups: groups),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('View all notifications'),
            ),
            if (snapshot.hasError)
              const LightStateView(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load notifications',
                message: 'Check your connection and try again.',
              )
            else if (notifications.isEmpty)
              const LightStateView(
                icon: Icons.notifications_none_rounded,
                title: 'No notifications yet',
                message: 'Your latest family updates will appear here.',
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        item.isRead
                            ? Icons.notifications_none_rounded
                            : Icons.notifications_active_rounded,
                        color: item.isRead ? Colors.grey : kEmerald,
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: item.isRead
                              ? FontWeight.w500
                              : FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: item.isRead
                          ? null
                          : () => service.markRead(user, item.id),
                    );
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}
