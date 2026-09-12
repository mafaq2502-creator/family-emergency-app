import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ProfileImageData {
  const ProfileImageData._();

  static const int maxBytes = 256 * 1024;

  static String encodeJpeg(Uint8List bytes) =>
      'data:image/jpeg;base64,${base64Encode(bytes)}';

  static ImageProvider<Object>? provider(String? source) {
    final value = source?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('data:image/')) {
      final separator = value.indexOf(',');
      if (separator < 0) return null;
      try {
        return MemoryImage(base64Decode(value.substring(separator + 1)));
      } on FormatException {
        return null;
      }
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return null;
    }
    return NetworkImage(value);
  }
}
