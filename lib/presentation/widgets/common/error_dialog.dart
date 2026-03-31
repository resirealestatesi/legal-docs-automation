import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;

  const ErrorDialog({
    super.key,
    this.title = 'Error',
    required this.message,
    this.buttonText = 'Aceptar',
  });

  static Future<void> show(
    BuildContext context, {
    String title = 'Error',
    required String message,
    String buttonText = 'Aceptar',
  }) {
    return showDialog(
      context: context,
      builder: (_) =>
          ErrorDialog(title: title, message: message, buttonText: buttonText),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(buttonText),
        ),
      ],
    );
  }
}
