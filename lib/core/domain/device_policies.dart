class DevicePolicy {
  const DevicePolicy._();

  static const heartbeatInterval = Duration(minutes: 15);
  static const minimumHeartbeatInterval = Duration(minutes: 1);
  static const staleAfter = Duration(minutes: 20);
  static const offlineAfter = Duration(minutes: 60);
  static const pairingLifetime = Duration(minutes: 10);
  static const maxNameLength = 80;
  static const installationIdLength = 32;
  static const pairingCodeLength = 24;

  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter a device name.';
    if (name.length > maxNameLength) {
      return 'Device name must be $maxNameLength characters or fewer.';
    }
    return null;
  }
}

class DevicePairingCodePolicy {
  const DevicePairingCodePolicy._();

  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String normalize(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static String format(String value) {
    final code = normalize(value);
    return [
      for (var index = 0; index < code.length; index += 4)
        code.substring(
          index,
          index + 4 > code.length ? code.length : index + 4,
        ),
    ].join('-');
  }

  static String? validate(String? value) {
    final code = normalize(value ?? '');
    if (code.isEmpty) return 'Enter a pairing code.';
    if (code.length != DevicePolicy.pairingCodeLength ||
        code.split('').any((character) => !alphabet.contains(character))) {
      return 'Enter a valid pairing code.';
    }
    return null;
  }

  static String? extract(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    final candidate =
        uri?.scheme == 'familyemergency' && uri?.host == 'pair-device'
        ? uri?.queryParameters['code']
        : trimmed;
    if (candidate == null || validate(candidate) != null) return null;
    return normalize(candidate);
  }
}
