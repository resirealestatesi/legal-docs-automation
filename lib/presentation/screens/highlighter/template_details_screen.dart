import 'package:flutter/material.dart';

class TemplateDetailsScreen extends StatelessWidget {
  final String templateId;

  const TemplateDetailsScreen({super.key, required this.templateId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalles de Plantilla')),
      body: Center(child: Text('Template ID: $templateId')),
    );
  }
}
