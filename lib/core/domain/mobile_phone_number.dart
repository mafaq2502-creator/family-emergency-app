class MobilePhoneNumber {
  const MobilePhoneNumber._();

  static String callingCode(String phoneCode) =>
      '+${phoneCode.replaceAll(RegExp(r'\D'), '')}';

  static String localDigits(String value, String phoneCode) {
    final raw = value.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final code = phoneCode.replaceAll(RegExp(r'\D'), '');
    if (raw.startsWith('+') && digits.startsWith(code)) {
      return digits.substring(code.length);
    }
    return digits;
  }

  static String normalize(String value, String phoneCode) =>
      '${callingCode(phoneCode)}${localDigits(value, phoneCode)}';

  static String localFromStored(String value, String phoneCode) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final code = phoneCode.replaceAll(RegExp(r'\D'), '');
    return value.trim().startsWith('+') && digits.startsWith(code)
        ? digits.substring(code.length)
        : digits;
  }

  static String? validateLocal(String? value, String phoneCode) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Please enter your mobile phone number.';
    if (!RegExp(r'^\+?[0-9\s().-]+$').hasMatch(raw) ||
        raw.indexOf('+') > 0 ||
        '+'.allMatches(raw).length > 1) {
      return 'Please enter a valid mobile phone number.';
    }
    final code = phoneCode.replaceAll(RegExp(r'\D'), '');
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (code.isEmpty || code.length > 3) {
      return 'Please select a valid country calling code.';
    }
    if (raw.startsWith('+') && !digits.startsWith(code)) {
      return 'Select the country code that matches this number.';
    }
    final normalized = normalize(raw, code);
    final totalDigits = normalized.replaceAll(RegExp(r'\D'), '').length;
    final local = localDigits(raw, code);
    if (local.length < 4 || totalDigits < 7 || totalDigits > 15) {
      return 'Mobile number must contain 7 to 15 digits including country code.';
    }
    return null;
  }
}
