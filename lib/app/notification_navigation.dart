import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/devices/presentation/device_screens.dart';
import '../features/groups/presentation/emergency_events_screen.dart';
import '../features/groups/presentation/join_requests_screen.dart';
import '../features/notifications/presentation/notification_center_screen.dart';
import '../features/progress/presentation/progress_detail_screens.dart';
import '../models/circle_role.dart';
import '../features/members/presentation/safety_users_screen.dart';
import '../features/groups/presentation/join_circle_screen.dart';
import '../models/family_group.dart';
import '../models/emergency_event.dart';
import '../models/paired_device.dart';
import '../features/groups/presentation/emergency_detail_screen.dart';

final authenticatedNavigatorKey = GlobalKey<NavigatorState>();
ValueChanged<int>? selectAuthenticatedSection;

final appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> openNotificationPayload(Map<String, dynamic> payload) async {
  final navigator =
      authenticatedNavigatorKey.currentState ?? appNavigatorKey.currentState;
  final user = FirebaseAuth.instance.currentUser;
  if (navigator == null || user == null) return;
  if (payload['recipientUid'] != null && payload['recipientUid'] != user.uid) {
    return;
  }
  final type = payload['type']?.toString() ?? 'general';
  if (type == 'safety_invite' || type == 'circle_invite') {
    selectAuthenticatedSection?.call(0);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => type == 'safety_invite'
            ? const SafetyUsersScreen(initialRequests: true)
            : const JoinCircleScreen(),
      ),
    );
    return;
  }
  final circleId = (payload['groupId'] ?? payload['circleId'])?.toString();
  FamilyGroup? group;
  try {
    if (circleId != null && circleId.isNotEmpty) {
      final snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(circleId)
          .get();
      final data = snapshot.data();
      if (data != null &&
          data['status'] == 'active' &&
          (data['memberIds'] as List? ?? []).contains(user.uid)) {
        final roles = Map<String, dynamic>.from(data['roles'] as Map? ?? {});
        group = FamilyGroup.fromMap(snapshot.id, {
          ...data,
          'role': roles[user.uid] ?? CircleRole.adult.value,
        });
      }
    }
  } catch (_) {
    // Revoked/deleted targets fall back to the user's notification history.
  }
  Widget? target;
  try {
    final emergencyId = payload['emergencyId']?.toString();
    if (type.startsWith('emergency') && group != null && emergencyId != null) {
      final event = await FirebaseFirestore.instance
          .collection('groups')
          .doc(group.id)
          .collection('emergencies')
          .doc(emergencyId)
          .get();
      if (event.data() != null) {
        target = EmergencyDetailScreen(
          group: group,
          event: EmergencyEvent.fromMap(event.id, event.data()!),
          currentUserName: user.displayName ?? 'You',
        );
      }
    }
    final deviceId = (payload['deviceId'] ?? payload['installationId'])
        ?.toString();
    if (type.contains('device') && deviceId != null) {
      final reference = group == null
          ? FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('devices')
                .doc(deviceId)
          : FirebaseFirestore.instance
                .collection('groups')
                .doc(group.id)
                .collection('devices')
                .doc(deviceId);
      final device = await reference.get();
      if (device.data() != null) {
        target = DeviceDetailScreen(
          memberName: 'Device',
          device: PairedDevice.fromMap(device.id, device.data()!),
          circleId: group?.id,
          accountDevice: group == null,
          canUnpair: group?.canManage ?? false,
        );
      }
    }
  } catch (_) {
    // Malformed payloads or unavailable records must never crash navigation.
  }
  if (!navigator.mounted ||
      FirebaseAuth.instance.currentUser?.uid != user.uid) {
    return;
  }
  if (target != null) {
    await navigator.push(MaterialPageRoute(builder: (_) => target!));
    return;
  }
  if (type.startsWith('emergency') && group != null) {
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => EmergencyEventsScreen(
          group: group!,
          currentUserName: user.displayName ?? 'You',
        ),
      ),
    );
  } else if (type.contains('join') && group != null && group.canManage) {
    await navigator.push(
      MaterialPageRoute(builder: (_) => JoinRequestsScreen(group: group!)),
    );
  } else if (type.contains('device')) {
    await navigator.push(
      MaterialPageRoute(builder: (_) => const DeviceListScreen()),
    );
  } else if (type.contains('check')) {
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ProgressDetailsScreen(
          circleId: circleId,
          memberUserId: payload['memberUserId']?.toString(),
        ),
      ),
    );
  } else {
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => NotificationCenterScreen(
          groups: group == null ? const [] : [group],
        ),
      ),
    );
  }
}
