import 'package:flutter/material.dart';

class BoundedDropdownFormField<T> extends StatelessWidget {
  const BoundedDropdownFormField({
    super.key,
    required this.items,
    required this.onChanged,
    this.initialValue,
    this.hint,
    this.decoration = const InputDecoration(),
    this.validator,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.menuMaxHeight = 360,
  });

  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final Widget? hint;
  final InputDecoration decoration;
  final FormFieldValidator<T>? validator;
  final AutovalidateMode autovalidateMode;
  final double menuMaxHeight;

  @override
  Widget build(BuildContext context) => FormField<T>(
    initialValue: initialValue,
    validator: validator,
    autovalidateMode: autovalidateMode,
    builder: (field) => LayoutBuilder(
      builder: (context, constraints) => InputDecorator(
        isEmpty: field.value == null,
        decoration: decoration.copyWith(errorText: field.errorText),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: field.value,
            items: items,
            hint: hint,
            isExpanded: true,
            menuWidth: constraints.maxWidth,
            menuMaxHeight: menuMaxHeight,
            borderRadius: BorderRadius.circular(12),
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            onChanged: onChanged == null
                ? null
                : (value) {
                    field.didChange(value);
                    onChanged!(value);
                  },
          ),
        ),
      ),
    ),
  );
}
