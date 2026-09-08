class NotificationSettings {
  const NotificationSettings({
    this.missedCheckInAlerts = true,
    this.emergencyAlerts = true,
    this.batteryAlerts = false,
    this.offlineAlerts = false,
    this.locationSharing = false,
    this.ownerMissedCheckInAlerts = true,
  });

  final bool missedCheckInAlerts;
  final bool emergencyAlerts;
  final bool batteryAlerts;
  final bool offlineAlerts;
  final bool locationSharing;
  final bool ownerMissedCheckInAlerts;

  factory NotificationSettings.fromMap(Map<String, dynamic>? map) =>
      NotificationSettings(
        missedCheckInAlerts: map?['missedCheckInAlerts'] as bool? ?? true,
        emergencyAlerts: map?['emergencyAlerts'] as bool? ?? true,
        batteryAlerts: map?['batteryAlerts'] as bool? ?? false,
        offlineAlerts: map?['offlineAlerts'] as bool? ?? false,
        locationSharing: map?['locationSharing'] as bool? ?? false,
        ownerMissedCheckInAlerts:
            map?['ownerMissedCheckInAlerts'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
    'missedCheckInAlerts': missedCheckInAlerts,
    'emergencyAlerts': emergencyAlerts,
    'batteryAlerts': batteryAlerts,
    'offlineAlerts': offlineAlerts,
    'locationSharing': locationSharing,
    'ownerMissedCheckInAlerts': ownerMissedCheckInAlerts,
  };
}
