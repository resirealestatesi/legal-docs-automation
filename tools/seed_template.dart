// tools/seed_template.dart
// Ejecutar: set SUPABASE_URL=https://xxx.supabase.co && set SUPABASE_ANON_KEY=xxx && dart run tools/seed_template.dart
//
// Inserta la plantilla "Contrato de Arrendamiento" y sus automatizaciones

import 'dart:convert';
import 'dart:io';

void main() async {
  final supabaseUrl = Platform.environment['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = Platform.environment['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    print('ERROR: Faltan SUPABASE_URL y SUPABASE_ANON_KEY');
    print(
      'Uso: set SUPABASE_URL=... && set SUPABASE_ANON_KEY=... && dart run tools/seed_template.dart',
    );
    exit(1);
  }

  final headers = {
    'apikey': supabaseAnonKey,
    'Authorization': 'Bearer $supabaseAnonKey',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  // Get first active company
  final companyRes = await _get(
    '$supabaseUrl/rest/v1/companies?select=id&is_active=eq.true&limit=1',
    headers,
  );
  final companyId = companyRes[0]['id'] as String;
  print('Empresa: $companyId');

  // Upload .docx to Storage
  final docxFile = File('tools/contrato_arrendamiento.docx');
  if (!await docxFile.exists()) {
    print('ERROR: No se encontro tools/contrato_arrendamiento.docx');
    exit(1);
  }

  final docxBytes = await docxFile.readAsBytes();
  final templateId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
  final storagePath = '$templateId/contrato_arrendamiento.docx';

  print('Subiendo .docx a Storage: $storagePath');

  final uploadRes = await HttpClient()
      .putUrl(Uri.parse(
    '$supabaseUrl/storage/v1/object/templates-docx/$storagePath',
  ))
      .then((req) {
    req.headers.set('apikey', supabaseAnonKey);
    req.headers.set('Authorization', 'Bearer $supabaseAnonKey');
    req.headers.set(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    req.headers.set('x-upsert', 'true');
    req.add(docxBytes);
    return req.close();
  });

  if (uploadRes.statusCode == 200) {
    print('OK .docx subido');
  } else {
    final body = await uploadRes.transform(utf8.decoder).join();
    print('ERROR subiendo .docx: ${uploadRes.statusCode} - $body');
    exit(1);
  }

  // Insert template
  print('Insertando plantilla...');
  await _post(
    '$supabaseUrl/rest/v1/templates',
    headers,
    {
      'id': templateId,
      'company_id': companyId,
      'name': 'Contrato de Arrendamiento',
      'description': 'Contrato estandar de arrendamiento de inmueble',
      'file_url': storagePath,
    },
  );
  print('OK Plantilla creada');

  // Insert automations
  final automations = [
    {
      'field_name': '[Persona] Nombre del Arrendador',
      'highlight_text': '{{NOMBRE_ARRENDADOR}}',
      'uppercase': true
    },
    {
      'field_name': '[Persona] Cedula del Arrendador',
      'highlight_text': '{{CEDULA_ARRENDADOR}}',
      'uppercase': true
    },
    {
      'field_name': '[Persona] Nombre del Arrendatario',
      'highlight_text': '{{NOMBRE_ARRENDATARIO}}',
      'uppercase': true
    },
    {
      'field_name': '[Persona] Cedula del Arrendatario',
      'highlight_text': '{{CEDULA_ARRENDATARIO}}',
      'uppercase': true
    },
    {
      'field_name': '[Inmueble] Direccion del Inmueble',
      'highlight_text': '{{DIRECCION_INMUEBLE}}',
      'uppercase': false
    },
    {
      'field_name': '[Lugar] Ciudad',
      'highlight_text': '{{CIUDAD}}',
      'uppercase': true
    },
    {
      'field_name': '[Fecha] Fecha de Inicio',
      'highlight_text': '{{FECHA_INICIO}}',
      'uppercase': false
    },
    {
      'field_name': '[Fecha] Fecha de Fin',
      'highlight_text': '{{FECHA_FIN}}',
      'uppercase': false
    },
    {
      'field_name': '[Monto] Monto de la Renta',
      'highlight_text': '{{MONTO_RENTA}}',
      'uppercase': true
    },
    {
      'field_name': '[Pago] Dia de Pago',
      'highlight_text': '{{DIA_PAGO}}',
      'uppercase': false
    },
    {
      'field_name': '[Monto] Monto de Garantia',
      'highlight_text': '{{MONTO_GARANTIA}}',
      'uppercase': true
    },
  ];

  print('Insertando ${automations.length} automatizaciones...');
  for (final auto in automations) {
    await _post(
      '$supabaseUrl/rest/v1/automations',
      headers,
      {
        'template_id': templateId,
        'field_name': auto['field_name'],
        'highlight_text': auto['highlight_text'],
        'field_options': <String>[],
        'uppercase': auto['uppercase'],
      },
    );
    print('  OK ${auto['field_name']}');
  }

  print('');
  print('========================================');
  print('Plantilla creada con exito!');
  print('ID: $templateId');
  print('Campos: ${automations.length}');
  print('========================================');
}

Future<List<dynamic>> _get(String url, Map<String, String> headers) async {
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse(url));
  headers.forEach(req.headers.set);
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return jsonDecode(body) as List<dynamic>;
  }
  throw Exception('GET $url failed: ${res.statusCode} - $body');
}

Future<void> _post(
    String url, Map<String, String> headers, Map<String, dynamic> data) async {
  final client = HttpClient();
  final req = await client.postUrl(Uri.parse(url));
  headers.forEach(req.headers.set);
  req.write(jsonEncode(data));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('POST $url failed: ${res.statusCode} - $body');
  }
}
