import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

/// ISO codes are stored internally; people choose and see country names.
class CountryNameField extends StatelessWidget {
  const CountryNameField({
    super.key,
    required this.countryIso,
    required this.onChanged,
    this.enabled = true,
  });

  final String? countryIso;
  final ValueChanged<Country> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final country = CountryService().findByCode(countryIso);
    return InkWell(
      onTap: !enabled
          ? null
          : () => showCountryPicker(
              context: context,
              showPhoneCode: false,
              onSelect: onChanged,
            ),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Country',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          enabled: enabled,
          prefixIcon: const Icon(Icons.public_rounded),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(country?.name ?? 'Select country'),
      ),
    );
  }
}
