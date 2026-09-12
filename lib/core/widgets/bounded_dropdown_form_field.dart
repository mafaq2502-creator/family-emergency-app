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
    key: ValueKey<Object?>(initialValue),
    initialValue: initialValue,
    validator: validator,
    autovalidateMode: autovalidateMode,
    builder: (field) => LayoutBuilder(
      builder: (context, constraints) {
        DropdownMenuItem<T>? selected;
        for (final item in items) {
          if (item.value == field.value) {
            selected = item;
            break;
          }
        }
        final hasSelection = selected != null;
        return MenuAnchor(
          alignmentOffset: Offset.zero,
          style: MenuStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
            maximumSize: WidgetStatePropertyAll(
              Size(constraints.maxWidth, menuMaxHeight),
            ),
          ),
          menuChildren: [
            SizedBox(
              width: constraints.maxWidth,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: menuMaxHeight),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in items)
                        MenuItemButton(
                          onPressed: onChanged == null || !item.enabled
                              ? null
                              : () {
                                  field.didChange(item.value);
                                  onChanged!(item.value);
                                },
                          child: SizedBox(
                            width: double.infinity,
                            child: DefaultTextStyle.merge(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              child: item.child,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          builder: (context, controller, child) => InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onChanged == null
                ? null
                : () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
            child: InputDecorator(
              isEmpty: !hasSelection,
              decoration: decoration.copyWith(
                errorText: field.errorText,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
              ),
              child: DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: selected?.child ?? hint ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    ),
  );
}
