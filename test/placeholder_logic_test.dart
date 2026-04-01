import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Placeholder Logic Tests', () {
    test('Sanitize field name correctly', () {
      final fieldName = '[Empresa] Nombre del Socio';
      final sanitized = fieldName
          .replaceAll(RegExp(r'[\[\]]'), '')
          .replaceAll(' ', '_')
          .toUpperCase();
      
      expect(sanitized, 'EMPRESA_NOMBRE_DEL_SOCIO');
    });

    test('Regex correctly finds placeholders in text', () {
      final text = 'Contrato con {{NOMBRE_SOCIO}} y {{EMPRESA}}.';
      final regex = RegExp(r'\{\{[^}]+\}\}');
      
      final matches = regex.allMatches(text).toList();
      
      expect(matches.length, 2);
      expect(matches[0].group(0), '{{NOMBRE_SOCIO}}');
      expect(matches[1].group(0), '{{EMPRESA}}');
    });

    test('Placeholder map lookup works', () {
      final placeholderMap = {
        '{{NOMBRE}}': {'id': '1', 'name': 'Nombre'},
      };
      
      final found = placeholderMap['{{NOMBRE}}'];
      expect(found?['id'], '1');
      
      final notFound = placeholderMap['{{OTRO}}'];
      expect(notFound, isNull);
    });
  });
}
