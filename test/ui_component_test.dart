import 'dart:typed_data';

import 'package:family_emergency_app/core/widgets/bounded_dropdown_form_field.dart';
import 'package:family_emergency_app/core/widgets/profile_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'profile image data supports stored JPEGs and rejects invalid sources',
    () {
      final encoded = ProfileImageData.encodeJpeg(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(encoded, startsWith('data:image/jpeg;base64,'));
      expect(ProfileImageData.provider(encoded), isA<MemoryImage>());
      expect(ProfileImageData.provider('data:image/jpeg;base64,%%%'), isNull);
      expect(ProfileImageData.provider('file:///private/photo.jpg'), isNull);
      expect(
        ProfileImageData.provider('https://example.com/photo.jpg'),
        isA<NetworkImage>(),
      );
    },
  );

  testWidgets('dropdown popup is constrained to its field width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: BoundedDropdownFormField<String>(
                initialValue: 'one',
                items: const [
                  DropdownMenuItem(value: 'one', child: Text('One')),
                  DropdownMenuItem(
                    value: 'two',
                    child: Text('A deliberately long second option'),
                  ),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();

    final popup = tester.getRect(find.byType(Scrollable).last);
    expect(popup.width, lessThanOrEqualTo(240));
  });
}
