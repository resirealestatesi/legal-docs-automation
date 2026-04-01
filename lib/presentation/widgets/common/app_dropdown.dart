import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';

class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? hintText;

  const AppDropdown({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.labelText,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: labelText, hintText: hintText),
      style: const TextStyle(color: AppColors.onSurface),
      borderRadius: BorderRadius.circular(12),
    );
  }
}
