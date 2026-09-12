import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/mobile_phone_number.dart';

class MobilePhoneField extends StatelessWidget {
  const MobilePhoneField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.enabled = true,
    this.required = true,
    this.textInputAction,
  });

  final TextEditingController controller;
  final Country country;
  final ValueChanged<Country> onCountryChanged;
  final bool enabled;
  final bool required;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 108,
        child: InkWell(
          key: const Key('mobile-country-code'),
          onTap: !enabled
              ? null
              : () => showCountryPicker(
                  context: context,
                  showPhoneCode: true,
                  onSelect: onCountryChanged,
                ),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Code',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: Icon(Icons.arrow_drop_down_rounded),
            ).copyWith(enabled: enabled),
            child: Text(
              MobilePhoneNumber.callingCode(country.phoneCode),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: TextFormField(
          key: const Key('mobile-phone-number'),
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          textInputAction: textInputAction,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: [_PhonePasteFormatter(country.phoneCode)],
          validator: (value) {
            if (!required && (value?.trim().isEmpty ?? true)) return null;
            return MobilePhoneNumber.validateLocal(value, country.phoneCode);
          },
          decoration: const InputDecoration(
            labelText: 'Mobile Phone Number',
            hintText: '300 1234567',
            prefixIcon: Icon(Icons.smartphone_rounded),
          ),
        ),
      ),
    ],
  );
}

class _PhonePasteFormatter extends TextInputFormatter {
  const _PhonePasteFormatter(this.phoneCode);

  final String phoneCode;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.trimLeft();
    final code = phoneCode.replaceAll(RegExp(r'\D'), '');
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (!raw.startsWith('+') || !digits.startsWith(code)) return newValue;
    final local = digits.substring(code.length);
    return TextEditingValue(
      text: local,
      selection: TextSelection.collapsed(offset: local.length),
    );
  }
}
