import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_colors.dart';

class CodeInputField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final bool isLoading;

  const CodeInputField({
    super.key,
    required this.controller,
    this.errorText,
    this.onSubmitted,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: !isLoading,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: AppColors.primary,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
            LengthLimitingTextInputFormatter(12),
            UpperCaseTextFormatter(),
          ],
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: 'LCC-2026',
            prefixIcon: const Icon(Icons.business, color: AppColors.primary),
            errorText: errorText,
          ),
        ),
      ],
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
