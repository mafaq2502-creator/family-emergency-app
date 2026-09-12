enum PushPermissionState {
  notRequested,
  granted,
  denied,
  settingsRequired,
  unavailable,
}

class PushPolicy {
  static PushPermissionState permission(
    Map<String, dynamic> status,
    bool requested,
  ) {
    if (status['notificationsEnabled'] is! bool ||
        status['runtimeGranted'] is! bool) {
      return PushPermissionState.unavailable;
    }
    if (status['notificationsEnabled'] == true &&
        status['runtimeGranted'] == true) {
      return PushPermissionState.granted;
    }
    if (status['requiresRuntimePermission'] != true ||
        status['runtimeGranted'] == true) {
      return PushPermissionState.settingsRequired;
    }
    if (!requested) return PushPermissionState.notRequested;
    return status['canShowRationale'] == true
        ? PushPermissionState.denied
        : PushPermissionState.settingsRequired;
  }

  static String channel(String? type) {
    if (type?.startsWith('emergency') ?? false) return 'emergency_sos';
    if (type?.contains('device') ?? false) return 'device_safety';
    if (type?.contains('join') ?? false) return 'family_activity';
    return 'general';
  }
}
