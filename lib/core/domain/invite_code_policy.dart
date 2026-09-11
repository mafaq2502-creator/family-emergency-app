class InviteCodePolicy {
  const InviteCodePolicy._();

  static const int length = 24;
  static const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final RegExp _valid = RegExp('^[$alphabet]{$length}\$');

  static String normalize(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    final candidate = uri?.scheme == 'familyemergency'
        ? uri?.queryParameters['code'] ?? ''
        : trimmed;
    return candidate.replaceAll(RegExp(r'[\s-]+'), '').toUpperCase();
  }

  static String? validate(String? value) {
    final normalized = normalize(value ?? '');
    if (normalized.isEmpty) return 'Enter an invitation code.';
    if (normalized.length != length || !_valid.hasMatch(normalized)) {
      return 'Enter a valid $length-character invitation code.';
    }
    return null;
  }

  static String display(String code) {
    final normalized = normalize(code);
    if (normalized.length != length) return normalized;
    return List.generate(
      length ~/ 4,
      (index) => normalized.substring(index * 4, index * 4 + 4),
    ).join('-');
  }

  static String qrPayload(String code) =>
      'familyemergency://join?code=${normalize(code)}';
}
