import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/app_notification.dart';
import '../../../models/family_group.dart';
import '../../../services/app_notification_service.dart';
import 'notification_banner.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key, this.groups = const []});

  final List<FamilyGroup> groups;

  @override
  Widget build(BuildContext context) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    if (user == null) {
      return IconButton(
        tooltip: 'Notifications',
        onPressed: null,
        icon: Icon(
          Icons.notifications_none_rounded,
          color: context.appMuted,
          size: 24,
        ),
      );
    }
    final signedInUser = user;
    return StreamBuilder<List<AppNotification>>(
      stream: AppNotificationService().watch(signedInUser),
      builder: (context, snapshot) {
        final unread = (snapshot.data ?? const <AppNotification>[])
            .where((item) => !item.isRead)
            .length;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () =>
              showNotificationBanner(context, signedInUser, groups: groups),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: Icon(
              Icons.notifications_none_rounded,
              color: context.appPrimary,
              size: 24,
            ),
          ),
        );
      },
    );
  }
}
