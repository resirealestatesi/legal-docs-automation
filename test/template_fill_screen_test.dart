import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:legal_docs_automation/presentation/screens/template/template_fill_screen.dart';
import 'package:legal_docs_automation/presentation/providers/template_provider.dart';

// Mocking Riverpod and other dependencies for widget test
void main() {
  testWidgets('TemplateFillScreen should show automations as placeholders', (WidgetTester tester) async {
    final templateId = 'temp-123';
    final automations = [
      {
        'id': 'auto-1',
        'template_id': templateId,
        'field_name': 'Nombre del Socio',
        'highlight_text': '{{NOMBRE_SOCIO}}',
        'field_options': [],
        'uppercase': false,
      }
    ];

    final documentText = 'Contrato con {{NOMBRE_SOCIO}}.';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          automationsProvider(templateId).overrideWith((ref) => automations),
        ],
        child: MaterialApp(
          home: TemplateFillScreen(
            template: {'id': templateId, 'name': 'Test Template', 'file_url': 'test.docx'},
            initialDocumentText: documentText,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that the placeholder is detected and rendered
    expect(find.text('{{NOMBRE_SOCIO}}'), findsOneWidget);
  });
}
