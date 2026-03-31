import 'package:flutter/material.dart';

class DocumentEditorScreen extends StatelessWidget {
  const DocumentEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editor de Documento')),
      body: const Center(child: Text('Editor de documento - Próximamente')),
    );
  }
}
